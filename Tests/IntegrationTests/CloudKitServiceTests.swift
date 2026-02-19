@testable import TheaCore
import XCTest

/// Tests for CloudKitService types and pure logic
@MainActor
final class CloudKitServiceTests: XCTestCase {

    // MARK: - CloudSyncStatus Tests

    func testCloudSyncStatusIdle() {
        let status = CloudSyncStatus.idle
        XCTAssertEqual(status.description, "Ready")
    }

    func testCloudSyncStatusSyncing() {
        let status = CloudSyncStatus.syncing
        XCTAssertEqual(status.description, "Syncing...")
    }

    func testCloudSyncStatusError() {
        let status = CloudSyncStatus.error("Network timeout")
        XCTAssertEqual(status.description, "Error: Network timeout")
    }

    func testCloudSyncStatusOffline() {
        let status = CloudSyncStatus.offline
        XCTAssertEqual(status.description, "Offline")
    }

    func testCloudSyncStatusEquality() {
        XCTAssertEqual(CloudSyncStatus.idle, CloudSyncStatus.idle)
        XCTAssertEqual(CloudSyncStatus.syncing, CloudSyncStatus.syncing)
        XCTAssertEqual(CloudSyncStatus.offline, CloudSyncStatus.offline)
        XCTAssertNotEqual(CloudSyncStatus.idle, CloudSyncStatus.syncing)
    }

    // MARK: - CloudKitError Tests

    func testCloudKitErrorDescriptions() {
        XCTAssertNotNil(CloudKitError.notAuthenticated.errorDescription)
        XCTAssertNotNil(CloudKitError.networkError.errorDescription)
        XCTAssertNotNil(CloudKitError.quotaExceeded.errorDescription)
        XCTAssertNotNil(CloudKitError.sharingFailed.errorDescription)
        XCTAssertNotNil(CloudKitError.recordNotFound.errorDescription)
        XCTAssertNotNil(CloudKitError.conflictDetected.errorDescription)
    }

    func testCloudKitErrorIsLocalizedError() {
        let error: Error = CloudKitError.notAuthenticated
        XCTAssertNotNil(error.localizedDescription)
    }

    // MARK: - CloudConversation Tests

    func testCloudConversationCreation() {
        let now = Date()
        let conversation = CloudConversation(
            id: UUID(),
            title: "Test Conversation",
            messages: [],
            aiModel: "gpt-4o",
            createdAt: now,
            modifiedAt: now,
            tags: ["test"],
            participatingDeviceIDs: ["device1"]
        )
        XCTAssertEqual(conversation.title, "Test Conversation")
        XCTAssertEqual(conversation.aiModel, "gpt-4o")
        XCTAssertTrue(conversation.messages.isEmpty)
        XCTAssertEqual(conversation.tags, ["test"])
        XCTAssertEqual(conversation.participatingDeviceIDs, ["device1"])
    }

    func testCloudConversationWithMessages() {
        let msg = CloudMessage(
            id: UUID(),
            content: "Hello",
            role: "user",
            timestamp: Date(),
            deviceID: "dev1",
            deviceName: "Mac Studio",
            deviceType: "macOS"
        )
        let conversation = CloudConversation(
            id: UUID(),
            title: "Chat",
            messages: [msg],
            aiModel: "claude-opus-4-5",
            createdAt: Date(),
            modifiedAt: Date(),
            tags: [],
            participatingDeviceIDs: []
        )
        XCTAssertEqual(conversation.messages.count, 1)
        XCTAssertEqual(conversation.messages.first?.content, "Hello")
        XCTAssertEqual(conversation.messages.first?.role, "user")
    }

    // MARK: - CloudMessage Tests

    func testCloudMessageCreation() {
        let id = UUID()
        let now = Date()
        let message = CloudMessage(
            id: id,
            content: "Test message",
            role: "assistant",
            timestamp: now,
            deviceID: "dev1",
            deviceName: "MacBook Air",
            deviceType: "macOS"
        )
        XCTAssertEqual(message.id, id)
        XCTAssertEqual(message.content, "Test message")
        XCTAssertEqual(message.role, "assistant")
        XCTAssertEqual(message.timestamp, now)
        XCTAssertEqual(message.deviceID, "dev1")
        XCTAssertEqual(message.deviceName, "MacBook Air")
    }

    func testCloudMessageWithoutDeviceInfo() {
        let message = CloudMessage(
            id: UUID(),
            content: "No device",
            role: "user",
            timestamp: Date(),
            deviceID: nil,
            deviceName: nil,
            deviceType: nil
        )
        XCTAssertNil(message.deviceID)
        XCTAssertNil(message.deviceName)
        XCTAssertNil(message.deviceType)
    }

    // MARK: - CloudSettings Tests

    func testCloudSettingsCreation() {
        let settings = CloudSettings(
            theme: "dark",
            aiModel: "gpt-4o",
            autoSave: true,
            syncEnabled: true,
            notificationsEnabled: false,
            modifiedAt: Date()
        )
        XCTAssertEqual(settings.theme, "dark")
        XCTAssertEqual(settings.aiModel, "gpt-4o")
        XCTAssertTrue(settings.autoSave)
        XCTAssertTrue(settings.syncEnabled)
        XCTAssertFalse(settings.notificationsEnabled)
    }

    // MARK: - CloudKnowledgeItem Tests

    func testCloudKnowledgeItemDefaults() {
        let id = UUID()
        let item = CloudKnowledgeItem(
            id: id,
            title: "Swift Concurrency",
            content: "Use async/await for concurrent operations",
            category: "programming",
            tags: ["swift", "concurrency"],
            source: "user",
            createdAt: Date()
        )
        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.title, "Swift Concurrency")
        XCTAssertEqual(item.category, "programming")
        XCTAssertEqual(item.tags.count, 2)
        XCTAssertTrue(item.tags.contains("swift"))
    }

    // MARK: - CloudProject Tests

    func testCloudProjectCreation() {
        let project = CloudProject(
            id: UUID(),
            name: "Thea",
            description: "AI assistant app",
            path: "/Users/alexis/Thea",
            tags: ["swift", "ai"],
            lastModified: Date()
        )
        XCTAssertEqual(project.name, "Thea")
        XCTAssertEqual(project.description, "AI assistant app")
        XCTAssertEqual(project.path, "/Users/alexis/Thea")
        XCTAssertEqual(project.tags, ["swift", "ai"])
    }

    // MARK: - Notification Names Tests

    func testCloudKitNotificationNamesExist() {
        // Verify all CloudKit notification names are properly defined
        XCTAssertNotNil(Notification.Name.cloudKitConversationDeleted)
        XCTAssertNotNil(Notification.Name.cloudKitSyncCompleted)
        XCTAssertNotNil(Notification.Name.cloudKitSyncFailed)
        XCTAssertNotNil(Notification.Name.cloudKitRequestLocalConversation)
        XCTAssertNotNil(Notification.Name.cloudKitSaveLocalConversation)
    }

    func testCloudKitNotificationNamesUnique() {
        // All notification names should be unique
        let names: [Notification.Name] = [
            .cloudKitConversationDeleted,
            .cloudKitSyncCompleted,
            .cloudKitSyncFailed,
            .cloudKitRequestLocalConversation,
            .cloudKitSaveLocalConversation
        ]
        let uniqueNames = Set(names.map(\.rawValue))
        XCTAssertEqual(uniqueNames.count, names.count)
    }
}
