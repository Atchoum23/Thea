// CloudKitTypesTests.swift
// Tests for CloudSyncStatus, CloudKitError, CloudMessage, and CloudConversation.
// CloudSettings, CloudKnowledgeItem, CloudProject, ConflictResolution, and merge
// logic tests are in CloudKitTypesMergeTests.swift.

import Foundation
import XCTest

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
}
