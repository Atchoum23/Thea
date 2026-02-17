//
//  CloudKitService+Merge.swift
//  Thea
//
//  Merge operations, conflict resolution, local storage helpers, and sharing
//

@preconcurrency import CloudKit
import Foundation

// MARK: - Merge Operations

extension CloudKitService {
    /// Merge a remote conversation with local data using intelligent conflict resolution
    func mergeConversation(_ remote: CloudConversation) async {
        let localConversation = await getLocalConversation(remote.id)

        if let local = localConversation {
            // Always merge to preserve messages from both sides
            let merged = mergeConversations(local: local, remote: remote)
            await saveLocalConversation(merged)

            // If local had changes not in remote, push the merged version
            let hasLocalOnlyMessages = local.messages.contains { localMsg in
                !remote.messages.contains { $0.id == localMsg.id }
            }
            if hasLocalOnlyMessages || local.modifiedAt > remote.modifiedAt {
                do {
                    try await saveConversation(merged, retryCount: 0)
                } catch {
                    logger.error("Failed to push merged conversation \(merged.id): \(error.localizedDescription)")
                }
            }
        } else {
            await saveLocalConversation(remote)
        }
    }

    /// Merge a remote knowledge item with local data
    func mergeKnowledgeItem(_ remote: CloudKnowledgeItem) async {
        let localItem = await getLocalKnowledgeItem(remote.id)

        if let local = localItem {
            // Use Last-Write-Wins strategy based on createdAt (knowledge items are immutable after creation)
            if remote.createdAt > local.createdAt {
                await saveLocalKnowledgeItem(remote)
            } else if local.createdAt > remote.createdAt {
                do {
                    try await saveKnowledgeItem(local)
                } catch {
                    logger.error("Failed to push knowledge item \(local.id): \(error.localizedDescription)")
                }
            }
        } else {
            await saveLocalKnowledgeItem(remote)
        }
    }

    /// Merge a remote project with local data
    func mergeProject(_ remote: CloudProject) async {
        let localProject = await getLocalProject(remote.id)

        if let local = localProject {
            // Use Last-Write-Wins strategy based on lastModified
            if remote.lastModified > local.lastModified {
                await saveLocalProject(remote)
            } else if local.lastModified > remote.lastModified {
                do {
                    try await saveProject(local)
                } catch {
                    logger.error("Failed to push project \(local.id): \(error.localizedDescription)")
                }
            }
            // Equal timestamps: prefer remote (other device's version) to ensure convergence
            else {
                await saveLocalProject(remote)
            }
        } else {
            await saveLocalProject(remote)
        }
    }

    /// Apply synced settings to local storage with field-level merge
    func applySettings(_ remote: CloudSettings) async {
        let localLastSync = lastSyncDate ?? .distantPast

        guard remote.modifiedAt > localLastSync else { return }

        // Apply remote settings — the receiving end should apply only
        // fields that differ from its current values
        NotificationCenter.default.post(
            name: .cloudKitApplySettings,
            object: nil,
            userInfo: [
                "settings": remote,
                "syncTimestamp": remote.modifiedAt
            ]
        )

        lastSyncDate = Date()
    }

    // MARK: - Local Storage Helpers

    /// Thread-safe local conversation fetch via notification.
    func getLocalConversation(_ id: UUID) async -> CloudConversation? {
        await withCheckedContinuation { continuation in
            nonisolated(unsafe) var hasResumed = false

            let observer = NotificationCenter.default.addObserver(
                forName: .cloudKitLocalConversationResponse,
                object: nil,
                queue: .main
            ) { notification in
                guard !hasResumed,
                      let responseID = notification.userInfo?["id"] as? UUID,
                      responseID == id
                else { return }
                hasResumed = true
                let conversation = notification.userInfo?["conversation"] as? CloudConversation
                continuation.resume(returning: conversation)
            }

            NotificationCenter.default.post(
                name: .cloudKitRequestLocalConversation,
                object: nil,
                userInfo: ["id": id]
            )

            // Timeout after 500ms if no response
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard !hasResumed else { return }
                hasResumed = true
                NotificationCenter.default.removeObserver(observer)
                continuation.resume(returning: nil)
            }
        }
    }

    func saveLocalConversation(_ conversation: CloudConversation) async {
        NotificationCenter.default.post(
            name: .cloudKitSaveLocalConversation,
            object: nil,
            userInfo: ["conversation": conversation]
        )
    }

    func getLocalKnowledgeItem(_ id: UUID) async -> CloudKnowledgeItem? {
        await withCheckedContinuation { continuation in
            nonisolated(unsafe) var hasResumed = false

            let observer = NotificationCenter.default.addObserver(
                forName: .cloudKitLocalKnowledgeItemResponse,
                object: nil,
                queue: .main
            ) { notification in
                guard !hasResumed,
                      let responseID = notification.userInfo?["id"] as? UUID,
                      responseID == id
                else { return }
                hasResumed = true
                let item = notification.userInfo?["item"] as? CloudKnowledgeItem
                continuation.resume(returning: item)
            }

            NotificationCenter.default.post(
                name: .cloudKitRequestLocalKnowledgeItem,
                object: nil,
                userInfo: ["id": id]
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard !hasResumed else { return }
                hasResumed = true
                NotificationCenter.default.removeObserver(observer)
                continuation.resume(returning: nil)
            }
        }
    }

    func saveLocalKnowledgeItem(_ item: CloudKnowledgeItem) async {
        NotificationCenter.default.post(
            name: .cloudKitSaveLocalKnowledgeItem,
            object: nil,
            userInfo: ["item": item]
        )
    }

    func getLocalProject(_ id: UUID) async -> CloudProject? {
        await withCheckedContinuation { continuation in
            nonisolated(unsafe) var hasResumed = false

            let observer = NotificationCenter.default.addObserver(
                forName: .cloudKitLocalProjectResponse,
                object: nil,
                queue: .main
            ) { notification in
                guard !hasResumed,
                      let responseID = notification.userInfo?["id"] as? UUID,
                      responseID == id
                else { return }
                hasResumed = true
                let project = notification.userInfo?["project"] as? CloudProject
                continuation.resume(returning: project)
            }

            NotificationCenter.default.post(
                name: .cloudKitRequestLocalProject,
                object: nil,
                userInfo: ["id": id]
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard !hasResumed else { return }
                hasResumed = true
                NotificationCenter.default.removeObserver(observer)
                continuation.resume(returning: nil)
            }
        }
    }

    func saveLocalProject(_ project: CloudProject) async {
        NotificationCenter.default.post(
            name: .cloudKitSaveLocalProject,
            object: nil,
            userInfo: ["project": project]
        )
    }

    // MARK: - Conflict Resolution

    public enum ConflictResolution {
        case keepLocal
        case keepRemote
        case merge
    }

    public func resolveConflict(
        local: CloudConversation,
        remote: CloudConversation,
        resolution: ConflictResolution
    ) async throws -> CloudConversation {
        switch resolution {
        case .keepLocal:
            try await saveConversation(local)
            return local
        case .keepRemote:
            await saveLocalConversation(remote)
            return remote
        case .merge:
            let merged = mergeConversations(local: local, remote: remote)
            try await saveConversation(merged)
            await saveLocalConversation(merged)
            return merged
        }
    }

    /// Merge two conversations by combining messages (deduplicated by ID),
    /// taking the newest metadata fields, and union of device/tag lists.
    func mergeConversations(local: CloudConversation, remote: CloudConversation) -> CloudConversation {
        // Deduplicate messages by ID, preferring the newer version of each
        var messagesByID: [UUID: CloudMessage] = [:]
        for msg in local.messages {
            messagesByID[msg.id] = msg
        }
        for msg in remote.messages {
            if let existing = messagesByID[msg.id] {
                // Keep whichever version is newer
                if msg.timestamp > existing.timestamp {
                    messagesByID[msg.id] = msg
                }
            } else {
                messagesByID[msg.id] = msg
            }
        }
        let mergedMessages = messagesByID.values.sorted { $0.timestamp < $1.timestamp }

        // Merge metadata: newest title, newest model, union of tags/devices
        let newestTitle = local.modifiedAt >= remote.modifiedAt ? local.title : remote.title
        let newestModel = local.modifiedAt >= remote.modifiedAt ? local.aiModel : remote.aiModel
        let mergedTags = Array(Set(local.tags + remote.tags)).sorted()
        let mergedDevices = Array(Set(local.participatingDeviceIDs + remote.participatingDeviceIDs))

        return CloudConversation(
            id: local.id,
            title: newestTitle,
            messages: mergedMessages,
            aiModel: newestModel,
            createdAt: min(local.createdAt, remote.createdAt),
            modifiedAt: max(local.modifiedAt, remote.modifiedAt),
            tags: mergedTags,
            participatingDeviceIDs: mergedDevices
        )
    }

    // MARK: - Sharing

    /// Share a conversation with another user
    public func shareConversation(_ conversationId: UUID, with participants: [CKShare.Participant]) async throws -> CKShare {
        guard let privateDatabase else { throw CloudKitError.notAuthenticated }
        let recordID = CKRecord.ID(recordName: "conversation-\(conversationId.uuidString)", zoneID: Self.theaZoneID)
        let record = try await privateDatabase.record(for: recordID)

        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = "Shared Conversation" as CKRecordValue
        share.publicPermission = .none

        for participant in participants {
            share.addParticipant(participant)
        }

        let results = try await privateDatabase.modifyRecords(saving: [record, share], deleting: [])

        guard let savedShare = try results.saveResults[share.recordID]?.get() as? CKShare else {
            throw CloudKitError.sharingFailed
        }

        return savedShare
    }
}
