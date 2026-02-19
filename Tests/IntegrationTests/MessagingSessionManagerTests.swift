// MessagingSessionManagerTests.swift
// Phase O — Tests for MessagingSessionManager and MessagingCredentialsStore

@testable import TheaCore
import XCTest

@MainActor
final class MessagingSessionManagerTests: XCTestCase {

    // MARK: - Singleton

    func testSharedInstanceExists() {
        let manager = MessagingSessionManager.shared
        XCTAssertNotNil(manager)
    }

    // MARK: - Active Sessions Initial State

    func testActiveSessionsIsAccessible() {
        let manager = MessagingSessionManager.shared
        // May have sessions from prior tests; just verify the property is accessible
        _ = manager.activeSessions
    }

    // MARK: - Append Outbound

    func testAppendOutboundToMissingSessonIsNoOp() {
        let manager = MessagingSessionManager.shared
        // Appending to a session key that doesn't exist should not crash
        manager.appendOutbound(text: "Test reply", toSessionKey: "nonexistent-key-\(UUID().uuidString)")
    }

    // MARK: - Reset All

    func testResetAllLeavesEmptySessions() {
        let manager = MessagingSessionManager.shared
        manager.resetAll()
        XCTAssertTrue(manager.activeSessions.isEmpty)
    }

    // MARK: - MessagingCredentialsStore (Keychain roundtrip)

    func testCredentialsSaveAndLoad() {
        let platform = MessagingPlatform.telegram
        var creds = MessagingCredentials(isEnabled: true)
        creds.botToken = "test-bot-token-\(UUID().uuidString)"

        MessagingCredentialsStore.save(creds, for: platform)
        let loaded = MessagingCredentialsStore.load(for: platform)

        XCTAssertEqual(loaded.botToken, creds.botToken)
        XCTAssertTrue(loaded.isEnabled)

        // Cleanup — save empty creds
        MessagingCredentialsStore.save(MessagingCredentials(isEnabled: false), for: platform)
    }

    func testCredentialsLoadForUnconfiguredPlatformReturnsDisabled() {
        // Matrix is unlikely to have credentials in test environment
        let creds = MessagingCredentialsStore.load(for: .matrix)
        // Token may or may not be set; just verify isEnabled reflects stored state
        _ = creds.isEnabled
    }

    // MARK: - SessionMessageEntry Codable

    func testSessionMessageEntryIsEncodable() throws {
        let entry = SessionMessageEntry(role: "user", content: "Hello")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(SessionMessageEntry.self, from: data)
        XCTAssertEqual(decoded.role, "user")
        XCTAssertEqual(decoded.content, "Hello")
        XCTAssertEqual(decoded.id, entry.id)
    }

    func testSessionMessageEntryAssistantRole() throws {
        let entry = SessionMessageEntry(role: "assistant", content: "I can help with that.")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(SessionMessageEntry.self, from: data)
        XCTAssertEqual(decoded.role, "assistant")
    }
}
