// CloudKitTypesMergeTests.swift
// Split from CloudKitTypesTests.swift — covers CloudSettings, CloudKnowledgeItem,
// CloudProject, ConflictResolution, and conversation merge logic tests.

import Foundation
import XCTest

final class CloudKitTypesMergeTests: XCTestCase {

    // MARK: - Mirrored Types (from CloudKitService.swift)

    struct CloudMessage: Sendable, Identifiable {
        let id: UUID
        let content: String
        let role: String
        let timestamp: Date
        let deviceID: String?
        let deviceName: String?
        let deviceType: String?
    }

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
        // Verify all cases exist and are distinct
        let cases: [ConflictResolution] = [.keepLocal, .keepRemote, .merge]
        XCTAssertEqual(cases.count, 3)

        // Verify cases are distinguishable via pattern matching
        for resolution in cases {
            switch resolution {
            case .keepLocal, .keepRemote, .merge:
                break
            }
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
