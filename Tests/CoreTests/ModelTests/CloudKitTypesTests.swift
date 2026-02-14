import Foundation
import XCTest

/// Standalone tests for CloudKit sync types:
/// CloudSyncStatus, CloudKitError, CloudConversation, CloudMessage,
/// CloudSettings, CloudKnowledgeItem, CloudProject.
/// These mirror the types defined in CloudKitService.swift.
final class CloudKitTypesTests: XCTestCase {

    // MARK: - CloudSyncStatus (mirror CloudKitService.swift)

    enum CloudSyncStatus: Sendable, Equatable {
        case idle
        case syncing
        case error(String)
        case offline

        var description: String {
            switch self {
            case .idle: "Ready"
            case .syncing: "Syncing..."
            case .error(let msg): "Error: \(msg)"
            case .offline: "Offline"
            }
        }
    }

    func testCloudSyncStatusIdleDescription() {
        XCTAssertEqual(CloudSyncStatus.idle.description, "Ready")
    }

    func testCloudSyncStatusSyncingDescription() {
        XCTAssertEqual(CloudSyncStatus.syncing.description, "Syncing...")
    }

    func testCloudSyncStatusErrorDescription() {
        let status = CloudSyncStatus.error("Network timeout")
        XCTAssertEqual(status.description, "Error: Network timeout")
    }

    func testCloudSyncStatusOfflineDescription() {
        XCTAssertEqual(CloudSyncStatus.offline.description, "Offline")
    }

    func testCloudSyncStatusEquality() {
        XCTAssertEqual(CloudSyncStatus.idle, CloudSyncStatus.idle)
        XCTAssertEqual(CloudSyncStatus.syncing, CloudSyncStatus.syncing)
        XCTAssertEqual(CloudSyncStatus.offline, CloudSyncStatus.offline)
        XCTAssertNotEqual(CloudSyncStatus.idle, CloudSyncStatus.syncing)
        XCTAssertNotEqual(CloudSyncStatus.idle, CloudSyncStatus.offline)
        XCTAssertNotEqual(CloudSyncStatus.syncing, CloudSyncStatus.offline)
    }

    func testCloudSyncStatusErrorEquality() {
        XCTAssertEqual(CloudSyncStatus.error("a"), CloudSyncStatus.error("a"))
        XCTAssertNotEqual(CloudSyncStatus.error("a"), CloudSyncStatus.error("b"))
        XCTAssertNotEqual(CloudSyncStatus.error("x"), CloudSyncStatus.idle)
    }

    func testCloudSyncStatusErrorWithEmptyMessage() {
        let status = CloudSyncStatus.error("")
        XCTAssertEqual(status.description, "Error: ")
    }

    // MARK: - CloudKitError (mirror CloudKitService.swift)

    enum CloudKitError: Error, LocalizedError {
        case notAuthenticated
        case networkError
        case quotaExceeded
        case sharingFailed
        case recordNotFound
        case conflictDetected

        var errorDescription: String? {
            switch self {
            case .notAuthenticated: "Not signed in to iCloud"
            case .networkError: "Network connection error"
            case .quotaExceeded: "iCloud storage quota exceeded"
            case .sharingFailed: "Failed to share content"
            case .recordNotFound: "Record not found"
            case .conflictDetected: "Sync conflict detected"
            }
        }
    }

    func testCloudKitErrorDescriptions() {
        XCTAssertEqual(CloudKitError.notAuthenticated.errorDescription, "Not signed in to iCloud")
        XCTAssertEqual(CloudKitError.networkError.errorDescription, "Network connection error")
        XCTAssertEqual(CloudKitError.quotaExceeded.errorDescription, "iCloud storage quota exceeded")
        XCTAssertEqual(CloudKitError.sharingFailed.errorDescription, "Failed to share content")
        XCTAssertEqual(CloudKitError.recordNotFound.errorDescription, "Record not found")
        XCTAssertEqual(CloudKitError.conflictDetected.errorDescription, "Sync conflict detected")
    }

    func testCloudKitErrorConformsToError() {
        let error: Error = CloudKitError.notAuthenticated
        XCTAssertNotNil(error.localizedDescription)
        XCTAssertFalse(error.localizedDescription.isEmpty)
    }

    func testCloudKitErrorAllCasesNonNilDescription() {
        let allErrors: [CloudKitError] = [
            .notAuthenticated, .networkError, .quotaExceeded,
            .sharingFailed, .recordNotFound, .conflictDetected
        ]
        for error in allErrors {
            XCTAssertNotNil(error.errorDescription, "\(error) should have description")
        }
    }

    // MARK: - CloudMessage (mirror CloudKitService.swift)

    struct CloudMessage: Sendable, Identifiable {
        let id: UUID
        let content: String
        let role: String
        let timestamp: Date
        let deviceID: String?
        let deviceName: String?
        let deviceType: String?
    }

    func testCloudMessageCreation() {
        let id = UUID()
        let now = Date()
        let msg = CloudMessage(
            id: id, content: "Hello", role: "user",
            timestamp: now, deviceID: "dev1",
            deviceName: "Mac Studio", deviceType: "macOS"
        )
        XCTAssertEqual(msg.id, id)
        XCTAssertEqual(msg.content, "Hello")
        XCTAssertEqual(msg.role, "user")
        XCTAssertEqual(msg.timestamp, now)
        XCTAssertEqual(msg.deviceID, "dev1")
        XCTAssertEqual(msg.deviceName, "Mac Studio")
        XCTAssertEqual(msg.deviceType, "macOS")
    }

    func testCloudMessageWithoutDeviceInfo() {
        let msg = CloudMessage(
            id: UUID(), content: "Test", role: "assistant",
            timestamp: Date(), deviceID: nil,
            deviceName: nil, deviceType: nil
        )
        XCTAssertNil(msg.deviceID)
        XCTAssertNil(msg.deviceName)
        XCTAssertNil(msg.deviceType)
    }

    func testCloudMessageRoles() {
        let roles = ["user", "assistant", "system"]
        for role in roles {
            let msg = CloudMessage(
                id: UUID(), content: "content", role: role,
                timestamp: Date(), deviceID: nil,
                deviceName: nil, deviceType: nil
            )
            XCTAssertEqual(msg.role, role)
        }
    }

    // MARK: - CloudConversation (mirror CloudKitService.swift)

    struct CloudConversation: Sendable, Identifiable {
        let id: UUID
        let title: String
        let messages: [CloudMessage]
        let aiModel: String
        let createdAt: Date
        let modifiedAt: Date
        let tags: [String]
        let participatingDeviceIDs: [String]
    }

    func testCloudConversationCreation() {
        let now = Date()
        let conv = CloudConversation(
            id: UUID(), title: "Test Chat", messages: [],
            aiModel: "gpt-4o", createdAt: now, modifiedAt: now,
            tags: ["test"], participatingDeviceIDs: ["device1"]
        )
        XCTAssertEqual(conv.title, "Test Chat")
        XCTAssertEqual(conv.aiModel, "gpt-4o")
        XCTAssertTrue(conv.messages.isEmpty)
        XCTAssertEqual(conv.tags, ["test"])
        XCTAssertEqual(conv.participatingDeviceIDs, ["device1"])
    }

    func testCloudConversationWithMessages() {
        let msg = CloudMessage(
            id: UUID(), content: "Hello AI", role: "user",
            timestamp: Date(), deviceID: "d1",
            deviceName: "MacBook", deviceType: "macOS"
        )
        let conv = CloudConversation(
            id: UUID(), title: "Chat", messages: [msg],
            aiModel: "claude-opus-4-5", createdAt: Date(), modifiedAt: Date(),
            tags: [], participatingDeviceIDs: []
        )
        XCTAssertEqual(conv.messages.count, 1)
        XCTAssertEqual(conv.messages.first?.content, "Hello AI")
    }

    func testCloudConversationMultipleDevices() {
        let conv = CloudConversation(
            id: UUID(), title: "Multi-device", messages: [],
            aiModel: "gpt-4o", createdAt: Date(), modifiedAt: Date(),
            tags: [], participatingDeviceIDs: ["mac-studio", "macbook-air", "iphone"]
        )
        XCTAssertEqual(conv.participatingDeviceIDs.count, 3)
        XCTAssertTrue(conv.participatingDeviceIDs.contains("mac-studio"))
        XCTAssertTrue(conv.participatingDeviceIDs.contains("macbook-air"))
    }

    // MARK: - CloudSettings (mirror CloudKitService.swift)

    struct CloudSettings: Sendable {
        let theme: String
        let aiModel: String
        let autoSave: Bool
        let syncEnabled: Bool
        let notificationsEnabled: Bool
        let modifiedAt: Date
    }

    func testCloudSettingsCreation() {
        let settings = CloudSettings(
            theme: "dark", aiModel: "gpt-4o",
            autoSave: true, syncEnabled: true,
            notificationsEnabled: false, modifiedAt: Date()
        )
        XCTAssertEqual(settings.theme, "dark")
        XCTAssertEqual(settings.aiModel, "gpt-4o")
        XCTAssertTrue(settings.autoSave)
        XCTAssertTrue(settings.syncEnabled)
        XCTAssertFalse(settings.notificationsEnabled)
    }

    func testCloudSettingsLightTheme() {
        let settings = CloudSettings(
            theme: "light", aiModel: "claude-sonnet-4-5",
            autoSave: false, syncEnabled: false,
            notificationsEnabled: true, modifiedAt: Date()
        )
        XCTAssertEqual(settings.theme, "light")
        XCTAssertFalse(settings.autoSave)
    }

    // MARK: - CloudKnowledgeItem (mirror CloudKitService.swift)

    struct CloudKnowledgeItem: Sendable, Identifiable {
        let id: UUID
        let title: String
        let content: String
        let category: String
        let tags: [String]
        let source: String
        let createdAt: Date
    }

    func testCloudKnowledgeItemCreation() {
        let id = UUID()
        let item = CloudKnowledgeItem(
            id: id, title: "Swift Concurrency",
            content: "Use async/await for concurrent operations",
            category: "programming", tags: ["swift", "concurrency"],
            source: "user", createdAt: Date()
        )
        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.title, "Swift Concurrency")
        XCTAssertEqual(item.category, "programming")
        XCTAssertEqual(item.tags.count, 2)
        XCTAssertTrue(item.tags.contains("swift"))
    }

    func testCloudKnowledgeItemEmptyTags() {
        let item = CloudKnowledgeItem(
            id: UUID(), title: "Note", content: "Content",
            category: "general", tags: [], source: "ai",
            createdAt: Date()
        )
        XCTAssertTrue(item.tags.isEmpty)
    }

    // MARK: - CloudProject (mirror CloudKitService.swift)

    struct CloudProject: Sendable, Identifiable {
        let id: UUID
        let name: String
        let description: String
        let path: String
        let tags: [String]
        let lastModified: Date
    }

    func testCloudProjectCreation() {
        let project = CloudProject(
            id: UUID(), name: "Thea",
            description: "AI assistant", path: "/Users/alexis/Thea",
            tags: ["swift", "ai"], lastModified: Date()
        )
        XCTAssertEqual(project.name, "Thea")
        XCTAssertEqual(project.description, "AI assistant")
        XCTAssertEqual(project.path, "/Users/alexis/Thea")
        XCTAssertEqual(project.tags, ["swift", "ai"])
    }

    // MARK: - ConflictResolution (mirror CloudKitService.swift)

    enum ConflictResolution {
        case keepLocal
        case keepRemote
        case merge
    }

    func testConflictResolutionCases() {
        let local = ConflictResolution.keepLocal
        let remote = ConflictResolution.keepRemote
        let merge = ConflictResolution.merge

        // Type check — ensures all cases exist
        switch local {
        case .keepLocal: break
        case .keepRemote: XCTFail("Expected keepLocal")
        case .merge: XCTFail("Expected keepLocal")
        }

        switch remote {
        case .keepRemote: break
        default: XCTFail("Expected keepRemote")
        }

        switch merge {
        case .merge: break
        default: XCTFail("Expected merge")
        }
    }

    // MARK: - Conversation Merge Logic (mirror CloudKitService.swift)

    func mergeConversations(local: CloudConversation, remote: CloudConversation) -> CloudConversation {
        // Deduplicate messages by ID, keeping newer timestamp
        var messageMap: [UUID: CloudMessage] = [:]
        for msg in local.messages {
            messageMap[msg.id] = msg
        }
        for msg in remote.messages {
            if let existing = messageMap[msg.id] {
                if msg.timestamp > existing.timestamp {
                    messageMap[msg.id] = msg
                }
            } else {
                messageMap[msg.id] = msg
            }
        }
        let mergedMessages = messageMap.values.sorted { $0.timestamp < $1.timestamp }

        // Merge metadata: newest title, newest model
        let title = local.modifiedAt > remote.modifiedAt ? local.title : remote.title
        let model = local.modifiedAt > remote.modifiedAt ? local.aiModel : remote.aiModel

        // Union of tags
        let mergedTags = Array(Set(local.tags + remote.tags)).sorted()

        // Union of devices
        let mergedDevices = Array(Set(local.participatingDeviceIDs + remote.participatingDeviceIDs))

        return CloudConversation(
            id: local.id,
            title: title,
            messages: mergedMessages,
            aiModel: model,
            createdAt: min(local.createdAt, remote.createdAt),
            modifiedAt: max(local.modifiedAt, remote.modifiedAt),
            tags: mergedTags,
            participatingDeviceIDs: mergedDevices
        )
    }

    func testMergeConversationsDeduplicatesMessages() {
        let sharedID = UUID()
        let now = Date()
        let earlier = now.addingTimeInterval(-60)

        let localMsg = CloudMessage(
            id: sharedID, content: "Old", role: "user",
            timestamp: earlier, deviceID: nil, deviceName: nil, deviceType: nil
        )
        let remoteMsg = CloudMessage(
            id: sharedID, content: "New", role: "user",
            timestamp: now, deviceID: nil, deviceName: nil, deviceType: nil
        )

        let local = CloudConversation(
            id: UUID(), title: "Local", messages: [localMsg],
            aiModel: "gpt-4o", createdAt: earlier, modifiedAt: earlier,
            tags: [], participatingDeviceIDs: []
        )
        let remote = CloudConversation(
            id: local.id, title: "Remote", messages: [remoteMsg],
            aiModel: "claude-opus-4-5", createdAt: earlier, modifiedAt: now,
            tags: [], participatingDeviceIDs: []
        )

        let merged = mergeConversations(local: local, remote: remote)
        XCTAssertEqual(merged.messages.count, 1, "Should deduplicate by ID")
        XCTAssertEqual(merged.messages.first?.content, "New", "Should keep newer")
    }

    func testMergeConversationsUnionsUniqueMessages() {
        let now = Date()
        let msg1 = CloudMessage(
            id: UUID(), content: "A", role: "user",
            timestamp: now, deviceID: nil, deviceName: nil, deviceType: nil
        )
        let msg2 = CloudMessage(
            id: UUID(), content: "B", role: "assistant",
            timestamp: now.addingTimeInterval(1), deviceID: nil,
            deviceName: nil, deviceType: nil
        )

        let local = CloudConversation(
            id: UUID(), title: "Chat", messages: [msg1],
            aiModel: "gpt-4o", createdAt: now, modifiedAt: now,
            tags: [], participatingDeviceIDs: []
        )
        let remote = CloudConversation(
            id: local.id, title: "Chat", messages: [msg2],
            aiModel: "gpt-4o", createdAt: now, modifiedAt: now,
            tags: [], participatingDeviceIDs: []
        )

        let merged = mergeConversations(local: local, remote: remote)
        XCTAssertEqual(merged.messages.count, 2, "Should union unique messages")
    }

    func testMergeConversationsUsesNewerTitle() {
        let now = Date()
        let earlier = now.addingTimeInterval(-60)

        let local = CloudConversation(
            id: UUID(), title: "Local Title", messages: [],
            aiModel: "gpt-4o", createdAt: earlier, modifiedAt: now,
            tags: [], participatingDeviceIDs: []
        )
        let remote = CloudConversation(
            id: local.id, title: "Remote Title", messages: [],
            aiModel: "claude-opus-4-5", createdAt: earlier, modifiedAt: earlier,
            tags: [], participatingDeviceIDs: []
        )

        let merged = mergeConversations(local: local, remote: remote)
        XCTAssertEqual(merged.title, "Local Title", "Should use title from newer modifiedAt")
        XCTAssertEqual(merged.aiModel, "gpt-4o", "Should use model from newer modifiedAt")
    }

    func testMergeConversationsUnionsTags() {
        let now = Date()
        let local = CloudConversation(
            id: UUID(), title: "Chat", messages: [],
            aiModel: "gpt-4o", createdAt: now, modifiedAt: now,
            tags: ["swift", "ai"], participatingDeviceIDs: []
        )
        let remote = CloudConversation(
            id: local.id, title: "Chat", messages: [],
            aiModel: "gpt-4o", createdAt: now, modifiedAt: now,
            tags: ["ai", "ios"], participatingDeviceIDs: []
        )

        let merged = mergeConversations(local: local, remote: remote)
        let tagSet = Set(merged.tags)
        XCTAssertEqual(tagSet.count, 3)
        XCTAssertTrue(tagSet.contains("swift"))
        XCTAssertTrue(tagSet.contains("ai"))
        XCTAssertTrue(tagSet.contains("ios"))
    }

    func testMergeConversationsUnionsDevices() {
        let now = Date()
        let local = CloudConversation(
            id: UUID(), title: "Chat", messages: [],
            aiModel: "gpt-4o", createdAt: now, modifiedAt: now,
            tags: [], participatingDeviceIDs: ["mac-studio"]
        )
        let remote = CloudConversation(
            id: local.id, title: "Chat", messages: [],
            aiModel: "gpt-4o", createdAt: now, modifiedAt: now,
            tags: [], participatingDeviceIDs: ["macbook-air"]
        )

        let merged = mergeConversations(local: local, remote: remote)
        let deviceSet = Set(merged.participatingDeviceIDs)
        XCTAssertEqual(deviceSet.count, 2)
        XCTAssertTrue(deviceSet.contains("mac-studio"))
        XCTAssertTrue(deviceSet.contains("macbook-air"))
    }

    func testMergeConversationsUsesOlderCreatedAt() {
        let now = Date()
        let earlier = now.addingTimeInterval(-3600)

        let local = CloudConversation(
            id: UUID(), title: "Chat", messages: [],
            aiModel: "gpt-4o", createdAt: now, modifiedAt: now,
            tags: [], participatingDeviceIDs: []
        )
        let remote = CloudConversation(
            id: local.id, title: "Chat", messages: [],
            aiModel: "gpt-4o", createdAt: earlier, modifiedAt: now,
            tags: [], participatingDeviceIDs: []
        )

        let merged = mergeConversations(local: local, remote: remote)
        XCTAssertEqual(merged.createdAt, earlier, "Should use older createdAt")
    }

    func testMergeConversationsUsesNewerModifiedAt() {
        let now = Date()
        let later = now.addingTimeInterval(3600)

        let local = CloudConversation(
            id: UUID(), title: "Chat", messages: [],
            aiModel: "gpt-4o", createdAt: now, modifiedAt: now,
            tags: [], participatingDeviceIDs: []
        )
        let remote = CloudConversation(
            id: local.id, title: "Chat", messages: [],
            aiModel: "gpt-4o", createdAt: now, modifiedAt: later,
            tags: [], participatingDeviceIDs: []
        )

        let merged = mergeConversations(local: local, remote: remote)
        XCTAssertEqual(merged.modifiedAt, later, "Should use newer modifiedAt")
    }

    // MARK: - Record Name Parsing (mirror CloudKitService.swift)

    func extractUUID(from recordName: String, prefix: String) -> UUID? {
        let parts = recordName.split(separator: "-", maxSplits: 1)
        guard parts.count == 2, String(parts[0]) == prefix else { return nil }
        return UUID(uuidString: String(parts[1]))
    }

    func testExtractUUIDFromConversationRecordName() {
        let id = UUID()
        let recordName = "conversation-\(id.uuidString)"
        let extracted = extractUUID(from: recordName, prefix: "conversation")
        XCTAssertEqual(extracted, id)
    }

    func testExtractUUIDFromKnowledgeRecordName() {
        let id = UUID()
        let recordName = "knowledge-\(id.uuidString)"
        let extracted = extractUUID(from: recordName, prefix: "knowledge")
        XCTAssertEqual(extracted, id)
    }

    func testExtractUUIDFromProjectRecordName() {
        let id = UUID()
        let recordName = "project-\(id.uuidString)"
        let extracted = extractUUID(from: recordName, prefix: "project")
        XCTAssertEqual(extracted, id)
    }

    func testExtractUUIDInvalidPrefix() {
        let id = UUID()
        let recordName = "conversation-\(id.uuidString)"
        let extracted = extractUUID(from: recordName, prefix: "project")
        XCTAssertNil(extracted)
    }

    func testExtractUUIDInvalidFormat() {
        let extracted = extractUUID(from: "invalid-format", prefix: "conversation")
        XCTAssertNil(extracted, "Should return nil for non-UUID suffix")
    }
}
