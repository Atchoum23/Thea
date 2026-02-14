// MonitoringAndCollaborationTypesTests.swift
// Tests for MonitoringService types and TeamKnowledgeBase types

import Testing
import Foundation

// MARK: - Test Doubles: MonitorType

private enum TestMonitorType: String, CaseIterable, Codable, Sendable {
    case appSwitch, idleTime, focusMode, screenTime, inputActivity

    var displayName: String {
        switch self {
        case .appSwitch: return "App Switching"
        case .idleTime: return "Idle Time"
        case .focusMode: return "Focus Mode"
        case .screenTime: return "Screen Time"
        case .inputActivity: return "Input Activity"
        }
    }

    var description: String {
        switch self {
        case .appSwitch: return "Tracks application switching patterns"
        case .idleTime: return "Monitors periods of inactivity"
        case .focusMode: return "Tracks Focus mode status changes"
        case .screenTime: return "Monitors overall screen usage duration"
        case .inputActivity: return "Tracks keyboard and mouse/trackpad activity"
        }
    }

    var icon: String {
        switch self {
        case .appSwitch: return "square.on.square"
        case .idleTime: return "moon.zzz"
        case .focusMode: return "moon.circle"
        case .screenTime: return "hourglass"
        case .inputActivity: return "keyboard"
        }
    }

    var requiredPermission: String {
        switch self {
        case .appSwitch, .screenTime: return "Accessibility"
        case .idleTime: return "None"
        case .focusMode: return "Focus"
        case .inputActivity: return "Input Monitoring"
        }
    }
}

// MARK: - Test Doubles: MonitoringConfiguration

private struct TestMonitoringConfig: Codable, Sendable, Equatable {
    var enabledMonitors: Set<TestMonitorType> = [.appSwitch, .idleTime]
    var samplingInterval: TimeInterval = 60
    var idleThresholdMinutes: Int = 5
    var retentionDays: Int = 30
    var encryptLogs: Bool = true
    var syncToCloud: Bool = false
}

// MARK: - Test Doubles: MonitoringError

private enum TestMonitoringError: Error, LocalizedError, Sendable {
    case permissionDenied
    case notMonitoring
    case monitorFailed(TestMonitorType, String)
    case alreadyMonitoring

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Permission denied for monitoring"
        case .notMonitoring: return "Monitoring is not active"
        case .monitorFailed(let type, let msg): return "\(type.displayName) failed: \(msg)"
        case .alreadyMonitoring: return "Monitoring is already active"
        }
    }
}

// MARK: - Test Doubles: ItemVisibility

private enum TestItemVisibility: String, Codable, Sendable, CaseIterable {
    case `private`, teamOnly, `public`
}

// MARK: - Test Doubles: SharedKnowledgeItem

private struct TestSharedKnowledgeItem: Identifiable, Codable, Sendable {
    let id: UUID
    let teamId: String
    var content: String
    var category: String
    var keywords: [String]
    let sharedBy: String
    let sharedAt: Date
    var lastModified: Date?
    var visibility: TestItemVisibility
    var version: Int

    init(id: UUID = UUID(), teamId: String, content: String, category: String, keywords: [String] = [], sharedBy: String, sharedAt: Date = Date(), lastModified: Date? = nil, visibility: TestItemVisibility = .teamOnly, version: Int = 1) {
        self.id = id
        self.teamId = teamId
        self.content = content
        self.category = category
        self.keywords = keywords
        self.sharedBy = sharedBy
        self.sharedAt = sharedAt
        self.lastModified = lastModified
        self.visibility = visibility
        self.version = version
    }
}

// MARK: - Test Doubles: TeamKnowledgeError

private enum TestTeamKnowledgeError: Error, LocalizedError, Sendable {
    case notAuthorized
    case syncFailed(String)
    case itemNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Not authorized to access team knowledge"
        case .syncFailed(let msg): return "Sync failed: \(msg)"
        case .itemNotFound: return "Knowledge item not found"
        }
    }
}

// MARK: - Test Doubles: Knowledge Search

private enum TestKnowledgeSearch {
    static func search(items: [TestSharedKnowledgeItem], query: String) -> [TestSharedKnowledgeItem] {
        let queryWords = Set(query.lowercased().split(separator: " ").map(String.init))
        return items.filter { item in
            let contentWords = Set(item.content.lowercased().split(separator: " ").map(String.init))
            let keywordWords = Set(item.keywords.map { $0.lowercased() })
            let combined = contentWords.union(keywordWords)
            return !queryWords.isDisjoint(with: combined)
        }
    }

    static func resolveConflict(remote: TestSharedKnowledgeItem, local: TestSharedKnowledgeItem) -> TestSharedKnowledgeItem {
        if remote.version > local.version { return remote }
        if local.version > remote.version { return local }
        // Same version — use most recent modification
        let remoteDate = remote.lastModified ?? remote.sharedAt
        let localDate = local.lastModified ?? local.sharedAt
        return remoteDate >= localDate ? remote : local
    }
}

// MARK: - Test Doubles: TeamKnowledgeConfig

private struct TestTeamKnowledgeConfig: Sendable {
    var syncInterval: TimeInterval = 300
    var maxItemsPerTeam: Int = 1000
    var defaultVisibility: TestItemVisibility = .teamOnly
    var enableConflictResolution: Bool = true
}

// MARK: - Tests: MonitorType

@Suite("Monitor Type")
struct MonitorTypeTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestMonitorType.allCases.count == 5)
    }

    @Test("Display names are unique")
    func displayNamesUnique() {
        let names = Set(TestMonitorType.allCases.map(\.displayName))
        #expect(names.count == TestMonitorType.allCases.count)
    }

    @Test("Descriptions are non-empty")
    func descriptions() {
        for monitor in TestMonitorType.allCases {
            #expect(!monitor.description.isEmpty)
        }
    }

    @Test("Icons are SF Symbol names")
    func icons() {
        for monitor in TestMonitorType.allCases {
            #expect(!monitor.icon.isEmpty)
            #expect(!monitor.icon.contains(" "))
        }
    }

    @Test("Required permissions are defined")
    func permissions() {
        for monitor in TestMonitorType.allCases {
            #expect(!monitor.requiredPermission.isEmpty)
        }
    }

    @Test("Idle time requires no permission")
    func idleTimeNoPermission() {
        #expect(TestMonitorType.idleTime.requiredPermission == "None")
    }

    @Test("Input activity requires Input Monitoring")
    func inputPermission() {
        #expect(TestMonitorType.inputActivity.requiredPermission == "Input Monitoring")
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for monitor in TestMonitorType.allCases {
            let data = try JSONEncoder().encode(monitor)
            let decoded = try JSONDecoder().decode(TestMonitorType.self, from: data)
            #expect(decoded == monitor)
        }
    }
}

// MARK: - Tests: MonitoringConfiguration

@Suite("Monitoring Configuration")
struct MonitoringConfigTests {
    @Test("Default configuration")
    func defaults() {
        let config = TestMonitoringConfig()
        #expect(config.enabledMonitors.count == 2)
        #expect(config.enabledMonitors.contains(.appSwitch))
        #expect(config.enabledMonitors.contains(.idleTime))
        #expect(config.samplingInterval == 60)
        #expect(config.idleThresholdMinutes == 5)
        #expect(config.retentionDays == 30)
        #expect(config.encryptLogs)
        #expect(!config.syncToCloud)
    }

    @Test("Equatable")
    func equatable() {
        let a = TestMonitoringConfig()
        let b = TestMonitoringConfig()
        #expect(a == b)
    }

    @Test("Equatable with differences")
    func equatableDiff() {
        var a = TestMonitoringConfig()
        var b = TestMonitoringConfig()
        b.samplingInterval = 120
        #expect(a != b)
        a.samplingInterval = 120
        #expect(a == b)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        var config = TestMonitoringConfig()
        config.enabledMonitors = [.focusMode, .screenTime]
        config.retentionDays = 90
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(TestMonitoringConfig.self, from: data)
        #expect(decoded.enabledMonitors.count == 2)
        #expect(decoded.retentionDays == 90)
    }
}

// MARK: - Tests: MonitoringError

@Suite("Monitoring Error")
struct MonitoringErrorTests {
    @Test("All errors have descriptions")
    func descriptions() {
        let errors: [TestMonitoringError] = [.permissionDenied, .notMonitoring, .monitorFailed(.inputActivity, "crash"), .alreadyMonitoring]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("Monitor failed includes type and message")
    func monitorFailedMsg() {
        let error = TestMonitoringError.monitorFailed(.screenTime, "timeout")
        let desc = error.errorDescription!
        #expect(desc.contains("Screen Time"))
        #expect(desc.contains("timeout"))
    }
}

// MARK: - Tests: ItemVisibility

@Suite("Item Visibility")
struct ItemVisibilityTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestItemVisibility.allCases.count == 3)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for vis in TestItemVisibility.allCases {
            let data = try JSONEncoder().encode(vis)
            let decoded = try JSONDecoder().decode(TestItemVisibility.self, from: data)
            #expect(decoded == vis)
        }
    }
}

// MARK: - Tests: SharedKnowledgeItem

@Suite("Shared Knowledge Item")
struct SharedKnowledgeItemTests {
    @Test("Creation with defaults")
    func creation() {
        let item = TestSharedKnowledgeItem(teamId: "team1", content: "Swift concurrency tips", category: "development", sharedBy: "alexis")
        #expect(item.teamId == "team1")
        #expect(item.visibility == .teamOnly)
        #expect(item.version == 1)
        #expect(item.lastModified == nil)
    }

    @Test("Identifiable")
    func identifiable() {
        let item1 = TestSharedKnowledgeItem(teamId: "t1", content: "a", category: "c", sharedBy: "u")
        let item2 = TestSharedKnowledgeItem(teamId: "t1", content: "b", category: "c", sharedBy: "u")
        #expect(item1.id != item2.id)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let item = TestSharedKnowledgeItem(teamId: "team1", content: "Test content", category: "testing", keywords: ["swift", "xcode"], sharedBy: "claude", visibility: .public, version: 3)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(TestSharedKnowledgeItem.self, from: data)
        #expect(decoded.teamId == "team1")
        #expect(decoded.version == 3)
        #expect(decoded.visibility == .public)
    }
}

// MARK: - Tests: TeamKnowledgeError

@Suite("Team Knowledge Error")
struct TeamKnowledgeErrorTests {
    @Test("All errors have descriptions")
    func descriptions() {
        let errors: [TestTeamKnowledgeError] = [.notAuthorized, .syncFailed("timeout"), .itemNotFound]
        for error in errors {
            #expect(error.errorDescription != nil)
        }
    }

    @Test("Sync failed includes message")
    func syncFailedMsg() {
        let error = TestTeamKnowledgeError.syncFailed("network unreachable")
        #expect(error.errorDescription!.contains("network unreachable"))
    }
}

// MARK: - Tests: Knowledge Search

@Suite("Knowledge Search")
struct KnowledgeSearchTests {
    private let items: [TestSharedKnowledgeItem] = [
        TestSharedKnowledgeItem(teamId: "t1", content: "Swift concurrency patterns with actors", category: "dev", keywords: ["swift", "concurrency"], sharedBy: "alice"),
        TestSharedKnowledgeItem(teamId: "t1", content: "UI testing best practices", category: "qa", keywords: ["testing", "ui"], sharedBy: "bob"),
        TestSharedKnowledgeItem(teamId: "t1", content: "CloudKit sync implementation guide", category: "dev", keywords: ["cloudkit", "sync"], sharedBy: "charlie")
    ]

    @Test("Search by content word")
    func searchByContent() {
        let results = TestKnowledgeSearch.search(items: items, query: "actors")
        #expect(results.count == 1)
        #expect(results.first?.content.contains("actors") == true)
    }

    @Test("Search by keyword")
    func searchByKeyword() {
        let results = TestKnowledgeSearch.search(items: items, query: "cloudkit")
        #expect(results.count == 1)
    }

    @Test("Search returns multiple matches")
    func multipleMatches() {
        let results = TestKnowledgeSearch.search(items: items, query: "swift testing")
        #expect(results.count >= 2)
    }

    @Test("Search with no matches")
    func noMatches() {
        let results = TestKnowledgeSearch.search(items: items, query: "python django")
        #expect(results.isEmpty)
    }

    @Test("Case-insensitive search")
    func caseInsensitive() {
        let results = TestKnowledgeSearch.search(items: items, query: "SWIFT")
        #expect(!results.isEmpty)
    }
}

// MARK: - Tests: Conflict Resolution

@Suite("Knowledge Conflict Resolution")
struct KnowledgeConflictResolutionTests {
    @Test("Higher version wins")
    func higherVersionWins() {
        let remote = TestSharedKnowledgeItem(teamId: "t1", content: "v3", category: "c", sharedBy: "a", version: 3)
        let local = TestSharedKnowledgeItem(teamId: "t1", content: "v2", category: "c", sharedBy: "a", version: 2)
        let winner = TestKnowledgeSearch.resolveConflict(remote: remote, local: local)
        #expect(winner.version == 3)
    }

    @Test("Local wins when higher version")
    func localHigherVersion() {
        let remote = TestSharedKnowledgeItem(teamId: "t1", content: "v1", category: "c", sharedBy: "a", version: 1)
        let local = TestSharedKnowledgeItem(teamId: "t1", content: "v4", category: "c", sharedBy: "a", version: 4)
        let winner = TestKnowledgeSearch.resolveConflict(remote: remote, local: local)
        #expect(winner.version == 4)
    }

    @Test("Same version: newer modification wins")
    func sameVersionNewerWins() {
        let now = Date()
        let remote = TestSharedKnowledgeItem(teamId: "t1", content: "remote", category: "c", sharedBy: "a", lastModified: now, version: 1)
        let local = TestSharedKnowledgeItem(teamId: "t1", content: "local", category: "c", sharedBy: "a", lastModified: now.addingTimeInterval(-60), version: 1)
        let winner = TestKnowledgeSearch.resolveConflict(remote: remote, local: local)
        #expect(winner.content == "remote")
    }

    @Test("Same version, no lastModified: uses sharedAt")
    func sameVersionNoModified() {
        let now = Date()
        let remote = TestSharedKnowledgeItem(teamId: "t1", content: "remote", category: "c", sharedBy: "a", sharedAt: now.addingTimeInterval(-120), version: 1)
        let local = TestSharedKnowledgeItem(teamId: "t1", content: "local", category: "c", sharedBy: "a", sharedAt: now, version: 1)
        let winner = TestKnowledgeSearch.resolveConflict(remote: remote, local: local)
        #expect(winner.content == "local")
    }
}

// MARK: - Tests: TeamKnowledgeConfig

@Suite("Team Knowledge Configuration")
struct TeamKnowledgeConfigTests {
    @Test("Default configuration")
    func defaults() {
        let config = TestTeamKnowledgeConfig()
        #expect(config.syncInterval == 300)
        #expect(config.maxItemsPerTeam == 1000)
        #expect(config.defaultVisibility == .teamOnly)
        #expect(config.enableConflictResolution)
    }
}
