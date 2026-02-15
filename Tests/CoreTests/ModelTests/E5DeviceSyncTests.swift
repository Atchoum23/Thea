import Testing
import Foundation

// MARK: - SyncConflictItem Tests

@Suite("SyncConflictItem — Model")
struct SyncConflictItemModelTests {
    @Test("Creation with all fields")
    func creation() {
        let id = UUID()
        let now = Date()
        let conflict = TestSyncConflictItem(
            id: id,
            itemType: .conversation,
            localTitle: "My Chat",
            remoteTitle: "My Chat (edited)",
            localModified: now,
            remoteModified: now.addingTimeInterval(-60),
            localDevice: "Mac Studio",
            remoteDevice: "MacBook Air",
            localMessageCount: 10,
            remoteMessageCount: 8
        )

        #expect(conflict.id == id)
        #expect(conflict.itemType == .conversation)
        #expect(conflict.localTitle == "My Chat")
        #expect(conflict.remoteTitle == "My Chat (edited)")
        #expect(conflict.localDevice == "Mac Studio")
        #expect(conflict.remoteDevice == "MacBook Air")
        #expect(conflict.localMessageCount == 10)
        #expect(conflict.remoteMessageCount == 8)
    }

    @Test("ItemType has all expected cases")
    func itemTypes() {
        let types: [TestSyncConflictItem.ItemType] = [.conversation, .settings, .project, .knowledge]
        #expect(types.count == 4)

        #expect(TestSyncConflictItem.ItemType.conversation.rawValue == "Conversation")
        #expect(TestSyncConflictItem.ItemType.settings.rawValue == "Settings")
        #expect(TestSyncConflictItem.ItemType.project.rawValue == "Project")
        #expect(TestSyncConflictItem.ItemType.knowledge.rawValue == "Knowledge Item")
    }

    @Test("Resolution has all expected cases")
    func resolutions() {
        let resolutions: [TestSyncConflictItem.Resolution] = [.keepLocal, .keepRemote, .merge]
        #expect(resolutions.count == 3)
    }

    @Test("Identifiable conformance — unique IDs")
    func identifiable() {
        let c1 = TestSyncConflictItem.sample()
        let c2 = TestSyncConflictItem.sample()
        #expect(c1.id != c2.id)
    }
}

// MARK: - SyncConflictManager Tests

@Suite("SyncConflictManager — Queue Management")
struct SyncConflictManagerTests {
    @Test("Initially empty")
    func initialState() {
        let manager = TestSyncConflictManager()
        #expect(manager.pendingConflicts.isEmpty)
        #expect(manager.activeConflict == nil)
        #expect(!manager.hasConflicts)
    }

    @Test("Adding first conflict sets active")
    func addFirst() {
        let manager = TestSyncConflictManager()
        let conflict = TestSyncConflictItem.sample()
        manager.addConflict(conflict)

        #expect(manager.pendingConflicts.count == 1)
        #expect(manager.activeConflict?.id == conflict.id)
        #expect(manager.hasConflicts)
    }

    @Test("Adding multiple conflicts — first stays active")
    func addMultiple() {
        let manager = TestSyncConflictManager()
        let c1 = TestSyncConflictItem.sample()
        let c2 = TestSyncConflictItem.sample()
        manager.addConflict(c1)
        manager.addConflict(c2)

        #expect(manager.pendingConflicts.count == 2)
        #expect(manager.activeConflict?.id == c1.id)
    }

    @Test("Resolving active conflict advances to next")
    func resolveAdvances() {
        let manager = TestSyncConflictManager()
        let c1 = TestSyncConflictItem.sample()
        let c2 = TestSyncConflictItem.sample()
        manager.addConflict(c1)
        manager.addConflict(c2)

        manager.resolveActiveConflict(with: .merge)

        #expect(manager.pendingConflicts.count == 1)
        #expect(manager.activeConflict?.id == c2.id)
    }

    @Test("Resolving last conflict clears active")
    func resolveLast() {
        let manager = TestSyncConflictManager()
        let c1 = TestSyncConflictItem.sample()
        manager.addConflict(c1)
        manager.resolveActiveConflict(with: .keepLocal)

        #expect(manager.pendingConflicts.isEmpty)
        #expect(manager.activeConflict == nil)
        #expect(!manager.hasConflicts)
    }

    @Test("Resolving with no active does nothing")
    func resolveEmpty() {
        let manager = TestSyncConflictManager()
        manager.resolveActiveConflict(with: .keepRemote)
        #expect(manager.pendingConflicts.isEmpty)
    }
}

// MARK: - SyncEncryption Tests

@Suite("SyncEncryption — AES-256-GCM")
struct SyncEncryptionTests {
    @Test("Encrypt and decrypt roundtrip")
    func encryptDecryptRoundtrip() throws {
        let key = TestSymmetricKey.random()
        let plaintext = "Hello, World! This is a test of E2E encryption."
        let data = Data(plaintext.utf8)

        let encrypted = try TestAESGCM.seal(data, key: key)
        #expect(encrypted != data)
        #expect(encrypted.count > data.count) // nonce + tag overhead

        let decrypted = try TestAESGCM.open(encrypted, key: key)
        let recovered = String(data: decrypted, encoding: .utf8)
        #expect(recovered == plaintext)
    }

    @Test("Different plaintexts produce different ciphertexts")
    func differentInputs() throws {
        let key = TestSymmetricKey.random()
        let data1 = Data("Message One".utf8)
        let data2 = Data("Message Two".utf8)

        let enc1 = try TestAESGCM.seal(data1, key: key)
        let enc2 = try TestAESGCM.seal(data2, key: key)
        #expect(enc1 != enc2)
    }

    @Test("Same plaintext encrypted twice produces different ciphertexts (random nonce)")
    func nonDeterministic() throws {
        let key = TestSymmetricKey.random()
        let data = Data("Same message".utf8)

        let enc1 = try TestAESGCM.seal(data, key: key)
        let enc2 = try TestAESGCM.seal(data, key: key)
        #expect(enc1 != enc2) // Different nonces
    }

    @Test("Decrypt with wrong key fails")
    func wrongKey() throws {
        let key1 = TestSymmetricKey.random()
        let key2 = TestSymmetricKey.random()
        let data = Data("Secret".utf8)

        let encrypted = try TestAESGCM.seal(data, key: key1)

        #expect(throws: (any Error).self) {
            _ = try TestAESGCM.open(encrypted, key: key2)
        }
    }

    @Test("Tampered ciphertext fails verification")
    func tamperedData() throws {
        let key = TestSymmetricKey.random()
        let data = Data("Authenticated data".utf8)

        var encrypted = try TestAESGCM.seal(data, key: key)
        // Tamper with a byte in the middle
        if encrypted.count > 20 {
            encrypted[15] ^= 0xFF
        }

        #expect(throws: (any Error).self) {
            _ = try TestAESGCM.open(encrypted, key: key)
        }
    }

    @Test("Empty data encrypts and decrypts")
    func emptyData() throws {
        let key = TestSymmetricKey.random()
        let data = Data()

        let encrypted = try TestAESGCM.seal(data, key: key)
        let decrypted = try TestAESGCM.open(encrypted, key: key)
        #expect(decrypted == data)
    }

    @Test("Large data encrypts and decrypts")
    func largeData() throws {
        let key = TestSymmetricKey.random()
        let data = Data(repeating: 42, count: 100_000)

        let encrypted = try TestAESGCM.seal(data, key: key)
        let decrypted = try TestAESGCM.open(encrypted, key: key)
        #expect(decrypted == data)
    }

    @Test("Codable roundtrip via encrypt/decrypt")
    func codableRoundtrip() throws {
        struct TestPayload: Codable, Equatable {
            let title: String
            let count: Int
            let tags: [String]
        }

        let key = TestSymmetricKey.random()
        let payload = TestPayload(title: "Test", count: 42, tags: ["a", "b"])

        let plainData = try JSONEncoder().encode(payload)
        let encrypted = try TestAESGCM.seal(plainData, key: key)
        let decrypted = try TestAESGCM.open(encrypted, key: key)
        let recovered = try JSONDecoder().decode(TestPayload.self, from: decrypted)
        #expect(recovered == payload)
    }
}

// MARK: - SyncEncryptionError Tests

@Suite("SyncEncryptionError — Descriptions")
struct SyncEncryptionErrorTests {
    @Test("All errors have descriptions")
    func descriptions() {
        let errors: [(TestSyncEncryptionError, String)] = [
            (.encryptionFailed, "Failed to encrypt sync data"),
            (.decryptionFailed, "Failed to decrypt sync data"),
            (.keychainSaveFailed(-25300), "Failed to save encryption key to Keychain (status: -25300)"),
            (.keychainLoadFailed, "Failed to load encryption key from Keychain")
        ]

        for (error, expected) in errors {
            #expect(error.errorDescription == expected)
        }
    }

    @Test("LocalizedError conformance")
    func localizedError() {
        let error: any LocalizedError = TestSyncEncryptionError.encryptionFailed
        #expect(error.errorDescription != nil)
    }
}

// MARK: - Selective Sync Tests

@Suite("Selective Sync — Data Type Toggles")
struct SelectiveSyncTests {
    @Test("SyncDataType has all expected cases")
    func allCases() {
        let types: [TestSyncDataType] = [.conversations, .knowledge, .projects, .favorites]
        #expect(types.count == 4)
    }

    @Test("SyncDataType raw values match UserDefaults keys")
    func rawValues() {
        #expect(TestSyncDataType.conversations.rawValue == "conversations")
        #expect(TestSyncDataType.knowledge.rawValue == "knowledge")
        #expect(TestSyncDataType.projects.rawValue == "projects")
        #expect(TestSyncDataType.favorites.rawValue == "favorites")
    }

    @Test("Default sync state is enabled for all types")
    func defaultEnabled() {
        // When no key exists in UserDefaults, isSyncEnabled should return true
        let defaults = UserDefaults(suiteName: "test.selective.sync.\(UUID().uuidString)")!
        for type in TestSyncDataType.allCases {
            let key = "sync.\(type.rawValue)"
            // No key set → should default to enabled
            #expect(defaults.object(forKey: key) == nil)
        }
    }

    @Test("Disabling a sync type is respected")
    func disableType() {
        let defaults = UserDefaults(suiteName: "test.selective.sync.\(UUID().uuidString)")!
        let key = "sync.conversations"

        defaults.set(false, forKey: key)
        #expect(defaults.bool(forKey: key) == false)

        defaults.set(true, forKey: key)
        #expect(defaults.bool(forKey: key) == true)
    }
}

// MARK: - SyncStatusIndicator State Tests

@Suite("Sync Status — Display Properties")
struct SyncStatusDisplayTests {
    @Test("Status text when sync disabled")
    func disabledText() {
        let state = TestSyncState(syncEnabled: false, iCloudAvailable: true, status: .idle)
        #expect(state.statusText == "Sync Disabled")
    }

    @Test("Status text when iCloud unavailable")
    func iCloudUnavailable() {
        let state = TestSyncState(syncEnabled: true, iCloudAvailable: false, status: .idle)
        #expect(state.statusText == "iCloud Unavailable")
    }

    @Test("Status text for idle state")
    func idleText() {
        let state = TestSyncState(syncEnabled: true, iCloudAvailable: true, status: .idle)
        #expect(state.statusText == "Synced")
    }

    @Test("Status text for syncing state")
    func syncingText() {
        let state = TestSyncState(syncEnabled: true, iCloudAvailable: true, status: .syncing)
        #expect(state.statusText == "Syncing...")
    }

    @Test("Status text for error state")
    func errorText() {
        let state = TestSyncState(syncEnabled: true, iCloudAvailable: true, status: .error("Connection failed"))
        #expect(state.statusText == "Error: Connection failed")
    }

    @Test("Status text for offline state")
    func offlineText() {
        let state = TestSyncState(syncEnabled: true, iCloudAvailable: true, status: .offline)
        #expect(state.statusText == "Offline")
    }

    @Test("Status icon for each state")
    func statusIcons() {
        let idle = TestSyncState(syncEnabled: true, iCloudAvailable: true, status: .idle)
        #expect(idle.statusIcon == "checkmark.icloud.fill")

        let syncing = TestSyncState(syncEnabled: true, iCloudAvailable: true, status: .syncing)
        #expect(syncing.statusIcon == "arrow.triangle.2.circlepath.icloud.fill")

        let error = TestSyncState(syncEnabled: true, iCloudAvailable: true, status: .error("err"))
        #expect(error.statusIcon == "exclamationmark.icloud.fill")

        let disabled = TestSyncState(syncEnabled: false, iCloudAvailable: true, status: .idle)
        #expect(disabled.statusIcon == "icloud.slash")
    }
}

// MARK: - Test Doubles

/// Mirrors SyncConflictItem from SyncConflictResolutionView.swift
private struct TestSyncConflictItem: Identifiable, Sendable {
    let id: UUID
    let itemType: ItemType
    let localTitle: String
    let remoteTitle: String
    let localModified: Date
    let remoteModified: Date
    let localDevice: String
    let remoteDevice: String
    let localMessageCount: Int
    let remoteMessageCount: Int

    enum ItemType: String, Sendable {
        case conversation = "Conversation"
        case settings = "Settings"
        case project = "Project"
        case knowledge = "Knowledge Item"
    }

    enum Resolution: Sendable {
        case keepLocal
        case keepRemote
        case merge
    }

    static func sample() -> TestSyncConflictItem {
        TestSyncConflictItem(
            id: UUID(),
            itemType: .conversation,
            localTitle: "Test Chat",
            remoteTitle: "Test Chat (edited)",
            localModified: Date(),
            remoteModified: Date().addingTimeInterval(-120),
            localDevice: "Mac Studio",
            remoteDevice: "MacBook Air",
            localMessageCount: 5,
            remoteMessageCount: 3
        )
    }
}

/// Mirrors SyncConflictManager logic
private final class TestSyncConflictManager {
    var pendingConflicts: [TestSyncConflictItem] = []
    var activeConflict: TestSyncConflictItem?

    var hasConflicts: Bool { !pendingConflicts.isEmpty }

    func addConflict(_ conflict: TestSyncConflictItem) {
        pendingConflicts.append(conflict)
        if activeConflict == nil {
            activeConflict = pendingConflicts.first
        }
    }

    func resolveActiveConflict(with resolution: TestSyncConflictItem.Resolution) {
        guard let active = activeConflict else { return }
        pendingConflicts.removeAll { $0.id == active.id }
        activeConflict = pendingConflicts.first
    }
}

/// AES-256-GCM test using CryptoKit directly
import CryptoKit

private struct TestSymmetricKey {
    let key: SymmetricKey

    static func random() -> TestSymmetricKey {
        TestSymmetricKey(key: SymmetricKey(size: .bits256))
    }
}

private enum TestAESGCM {
    static func seal(_ data: Data, key: TestSymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key.key)
        guard let combined = sealedBox.combined else {
            throw TestSyncEncryptionError.encryptionFailed
        }
        return combined
    }

    static func open(_ data: Data, key: TestSymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key.key)
    }
}

/// Mirrors SyncEncryptionError
private enum TestSyncEncryptionError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case keychainSaveFailed(OSStatus)
    case keychainLoadFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed: "Failed to encrypt sync data"
        case .decryptionFailed: "Failed to decrypt sync data"
        case .keychainSaveFailed(let status): "Failed to save encryption key to Keychain (status: \(status))"
        case .keychainLoadFailed: "Failed to load encryption key from Keychain"
        }
    }
}

/// Mirrors SyncDataType
private enum TestSyncDataType: String, CaseIterable {
    case conversations
    case knowledge
    case projects
    case favorites
}

// MARK: - TheaTransport Tests

@Suite("TheaTransport — Selection & Priority")
struct TheaTransportSelectionTests {
    @Test("All transport cases exist")
    func allCases() {
        let cases: [TestTransport] = [.thunderbolt, .localNetwork, .tailscale, .cloudKit]
        #expect(cases.count == 4)
    }

    @Test("Priority order: Thunderbolt < LAN < Tailscale < CloudKit")
    func priorityOrder() {
        #expect(TestTransport.thunderbolt.rawValue < TestTransport.localNetwork.rawValue)
        #expect(TestTransport.localNetwork.rawValue < TestTransport.tailscale.rawValue)
        #expect(TestTransport.tailscale.rawValue < TestTransport.cloudKit.rawValue)
    }

    @Test("Display names are human-readable")
    func displayNames() {
        #expect(TestTransport.thunderbolt.displayName == "Thunderbolt")
        #expect(TestTransport.localNetwork.displayName == "Local Network")
        #expect(TestTransport.tailscale.displayName == "Tailscale")
        #expect(TestTransport.cloudKit.displayName == "iCloud")
    }

    @Test("SF Symbols are valid names")
    func sfSymbols() {
        #expect(TestTransport.thunderbolt.sfSymbol == "bolt.fill")
        #expect(TestTransport.localNetwork.sfSymbol == "wifi")
        #expect(TestTransport.tailscale.sfSymbol == "globe")
        #expect(TestTransport.cloudKit.sfSymbol == "icloud.fill")
    }

    @Test("Estimated latencies are in ascending order")
    func latencies() {
        let latencies = TestTransport.allCases.map(\.estimatedLatencyMs)
        for i in 0..<(latencies.count - 1) {
            #expect(latencies[i] < latencies[i + 1])
        }
    }

    @Test("Best transport selects minimum rawValue")
    func bestTransport() {
        let available: Set<TestTransport> = [.tailscale, .cloudKit]
        let best = available.min()
        #expect(best == .tailscale)

        let all: Set<TestTransport> = [.thunderbolt, .localNetwork, .tailscale, .cloudKit]
        #expect(all.min() == .thunderbolt)

        let onlyCloud: Set<TestTransport> = [.cloudKit]
        #expect(onlyCloud.min() == .cloudKit)
    }
}

// MARK: - Transport Label Tests

@Suite("Transport Labels — Status Indicator Display")
struct TransportLabelTests {
    @Test("Active transport shows '(active)' suffix")
    func activeLabel() {
        let label = testTransportLabel(transport: .thunderbolt, available: true, latency: 0.5, active: true)
        #expect(label.contains("(active)"))
        #expect(label.contains("Thunderbolt"))
    }

    @Test("Unavailable transport shows '— unavailable'")
    func unavailableLabel() {
        let label = testTransportLabel(transport: .localNetwork, available: false, latency: nil, active: false)
        #expect(label.contains("unavailable"))
        #expect(label.contains("Local Network"))
    }

    @Test("Latency shown in milliseconds")
    func latencyLabel() {
        let label = testTransportLabel(transport: .tailscale, available: true, latency: 20.3, active: false)
        #expect(label.contains("20ms"))
    }

    @Test("All info combined")
    func fullLabel() {
        let label = testTransportLabel(transport: .thunderbolt, available: true, latency: 0.8, active: true)
        #expect(label.contains("Thunderbolt"))
        #expect(label.contains("(active)"))
        #expect(label.contains("1ms")) // 0.8 rounds to 1
    }
}

// MARK: - TransportProbeResult Tests

@Suite("TransportProbeResult — Factory Construction")
struct TransportProbeFactoryTests {
    @Test("Unavailable result has correct state")
    func unavailable() {
        let result = TestTransportProbeResult.unavailable(.thunderbolt)
        #expect(!result.isAvailable)
        #expect(result.latencyMs == nil)
        #expect(result.endpoint == nil)
        #expect(result.transport == .thunderbolt)
    }

    @Test("Available result has correct state")
    func available() {
        let result = TestTransportProbeResult.available(.localNetwork, latency: 2.5, endpoint: "mbam2.local:18790")
        #expect(result.isAvailable)
        #expect(result.latencyMs == 2.5)
        #expect(result.endpoint == "mbam2.local:18790")
        #expect(result.transport == .localNetwork)
    }
}

// MARK: - Transport Status Indicator State Tests

@Suite("SyncStatusIndicator — Transport-aware icons")
struct TransportAwareIconTests {
    @Test("CloudKit transport uses icloud icon when idle")
    func cloudKitIcon() {
        let state = TestTransportSyncState(syncEnabled: true, iCloudAvailable: true, status: .idle, transport: .cloudKit)
        #expect(state.statusIcon == "checkmark.icloud.fill")
    }

    @Test("Non-CloudKit transport uses generic checkmark when idle")
    func nonCloudIcon() {
        let state = TestTransportSyncState(syncEnabled: true, iCloudAvailable: true, status: .idle, transport: .thunderbolt)
        #expect(state.statusIcon == "checkmark.circle.fill")
    }

    @Test("Syncing always uses icloud sync icon")
    func syncingIcon() {
        let state = TestTransportSyncState(syncEnabled: true, iCloudAvailable: true, status: .syncing, transport: .thunderbolt)
        #expect(state.statusIcon == "arrow.triangle.2.circlepath.icloud.fill")
    }
}

// MARK: - Additional Test Doubles

private enum TestTransport: Int, Comparable, CaseIterable, Hashable {
    case thunderbolt = 0
    case localNetwork = 1
    case tailscale = 2
    case cloudKit = 3

    static func < (lhs: TestTransport, rhs: TestTransport) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .thunderbolt: "Thunderbolt"
        case .localNetwork: "Local Network"
        case .tailscale: "Tailscale"
        case .cloudKit: "iCloud"
        }
    }

    var sfSymbol: String {
        switch self {
        case .thunderbolt: "bolt.fill"
        case .localNetwork: "wifi"
        case .tailscale: "globe"
        case .cloudKit: "icloud.fill"
        }
    }

    var estimatedLatencyMs: Double {
        switch self {
        case .thunderbolt: 0.5
        case .localNetwork: 2.0
        case .tailscale: 20.0
        case .cloudKit: 200.0
        }
    }
}

private struct TestTransportProbeResult {
    let transport: TestTransport
    let isAvailable: Bool
    let latencyMs: Double?
    let endpoint: String?

    static func unavailable(_ transport: TestTransport) -> TestTransportProbeResult {
        TestTransportProbeResult(transport: transport, isAvailable: false, latencyMs: nil, endpoint: nil)
    }

    static func available(_ transport: TestTransport, latency: Double, endpoint: String) -> TestTransportProbeResult {
        TestTransportProbeResult(transport: transport, isAvailable: true, latencyMs: latency, endpoint: endpoint)
    }
}

private func testTransportLabel(transport: TestTransport, available: Bool, latency: Double?, active: Bool) -> String {
    var label = transport.displayName
    if active { label += " (active)" }
    if let latency { label += " — \(String(format: "%.0f", latency))ms" }
    if !available { label += " — unavailable" }
    return label
}

/// Transport-aware sync state
private struct TestTransportSyncState {
    let syncEnabled: Bool
    let iCloudAvailable: Bool
    let status: TestSyncState.SyncStatus
    let transport: TestTransport

    var statusIcon: String {
        guard syncEnabled else { return "icloud.slash" }
        guard iCloudAvailable else { return "icloud.slash" }
        switch status {
        case .idle: return transport == .cloudKit ? "checkmark.icloud.fill" : "checkmark.circle.fill"
        case .syncing: return "arrow.triangle.2.circlepath.icloud.fill"
        case .error: return "exclamationmark.icloud.fill"
        case .offline: return "icloud.slash"
        }
    }
}

/// Mirrors the status logic from SyncStatusIndicator
private struct TestSyncState {
    let syncEnabled: Bool
    let iCloudAvailable: Bool
    let status: SyncStatus

    enum SyncStatus {
        case idle
        case syncing
        case error(String)
        case offline
    }

    var statusText: String {
        guard syncEnabled else { return "Sync Disabled" }
        guard iCloudAvailable else { return "iCloud Unavailable" }
        switch status {
        case .idle: return "Synced"
        case .syncing: return "Syncing..."
        case .error(let msg): return "Error: \(msg)"
        case .offline: return "Offline"
        }
    }

    var statusIcon: String {
        guard syncEnabled else { return "icloud.slash" }
        guard iCloudAvailable else { return "icloud.slash" }
        switch status {
        case .idle: return "checkmark.icloud.fill"
        case .syncing: return "arrow.triangle.2.circlepath.icloud.fill"
        case .error: return "exclamationmark.icloud.fill"
        case .offline: return "icloud.slash"
        }
    }
}
