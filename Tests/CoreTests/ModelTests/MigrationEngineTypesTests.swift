// MigrationEngineTypesTests.swift
// Tests for MigrationEngine types: stages, options, estimates, sources, progress

import Testing
import Foundation

// MARK: - Test Doubles: MigrationStage

private enum TestMigrationStage: String, Sendable, CaseIterable {
    case scanning, conversations, projects, attachments, settings, finalizing, complete

    var isComplete: Bool { self == .complete }

    var order: Int {
        switch self {
        case .scanning: return 0
        case .conversations: return 1
        case .projects: return 2
        case .attachments: return 3
        case .settings: return 4
        case .finalizing: return 5
        case .complete: return 6
        }
    }
}

// MARK: - Test Doubles: MigrationOptions

private struct TestMigrationOptions: Sendable {
    var includeConversations: Bool = true
    var includeProjects: Bool = true
    var includeSettings: Bool = true
    var includeAttachments: Bool = true
    var deduplicateConversations: Bool = true
}

// MARK: - Test Doubles: MigrationEstimate

private struct TestMigrationEstimate: Sendable {
    var conversationCount: Int
    var projectCount: Int
    var attachmentCount: Int
    var totalSizeBytes: Int64
    var estimatedDurationSeconds: Int

    var formattedSize: String {
        let bytes = Double(totalSizeBytes)
        if bytes >= 1_073_741_824 {
            return String(format: "%.1f GB", bytes / 1_073_741_824)
        } else if bytes >= 1_048_576 {
            return String(format: "%.1f MB", bytes / 1_048_576)
        } else if bytes >= 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        }
        return "\(totalSizeBytes) bytes"
    }

    var totalItems: Int {
        conversationCount + projectCount + attachmentCount
    }
}

// MARK: - Test Doubles: MigrationProgress

private struct TestMigrationProgress: Sendable {
    let stage: TestMigrationStage
    let currentItem: String
    let itemsProcessed: Int
    let totalItems: Int

    var percentage: Double {
        guard totalItems > 0 else { return 0 }
        return min(Double(itemsProcessed) / Double(totalItems) * 100, 100)
    }
}

// MARK: - Test Doubles: MigrationStats

private struct TestMigrationStats: Sendable {
    var conversationCount: Int = 0
    var messageCount: Int = 0
    var projectCount: Int = 0
    var attachmentCount: Int = 0

    var totalItems: Int {
        conversationCount + messageCount + projectCount + attachmentCount
    }
}

// MARK: - Test Doubles: MigrationStatus

private enum TestMigrationStatus: Sendable {
    case running
    case completed
    case failed(String)

    var isTerminal: Bool {
        switch self {
        case .running: return false
        case .completed, .failed: return true
        }
    }
}

// MARK: - Test Doubles: MigrationError

private enum TestMigrationError: Error, LocalizedError, Sendable {
    case manualExportRequired
    case webBasedApp
    case notImplemented
    case noModelContext

    var errorDescription: String? {
        switch self {
        case .manualExportRequired: return "Manual export is required for this source"
        case .webBasedApp: return "This is a web-based app and cannot be migrated directly"
        case .notImplemented: return "Migration from this source is not yet implemented"
        case .noModelContext: return "No model context available for migration"
        }
    }
}

// MARK: - Test Doubles: MigrationSourceInfo

private struct TestMigrationSourceInfo: Sendable {
    let sourceName: String
    let sourceIcon: String
    let sourceDescription: String
    let isInstalled: Bool
    let supportedPlatform: String

    static let allSources: [TestMigrationSourceInfo] = [
        TestMigrationSourceInfo(sourceName: "Claude App", sourceIcon: "sparkle", sourceDescription: "Import from Anthropic Claude desktop app", isInstalled: true, supportedPlatform: "macOS"),
        TestMigrationSourceInfo(sourceName: "ChatGPT", sourceIcon: "bubble.left.and.text.bubble.right", sourceDescription: "Import from OpenAI ChatGPT", isInstalled: false, supportedPlatform: "macOS"),
        TestMigrationSourceInfo(sourceName: "Cursor", sourceIcon: "cursorarrow", sourceDescription: "Import from Cursor IDE", isInstalled: true, supportedPlatform: "macOS"),
        TestMigrationSourceInfo(sourceName: "Perplexity", sourceIcon: "globe", sourceDescription: "Import from Perplexity", isInstalled: false, supportedPlatform: "macOS"),
        TestMigrationSourceInfo(sourceName: "Claude Code CLI", sourceIcon: "terminal", sourceDescription: "Import from Claude Code CLI sessions", isInstalled: true, supportedPlatform: "macOS")
    ]
}

// MARK: - Test Doubles: MigratedMessage

private struct TestMigratedMessage: Sendable {
    enum Role: String, Sendable { case user, assistant, system }
    enum Content: Sendable {
        case text(String)
        case multipart([String])
    }

    let role: Role
    let content: Content
    let timestamp: Date
}

// MARK: - Test Doubles: MigratedConversation

private struct TestMigratedConversation: Sendable {
    let title: String
    let messages: [TestMigratedMessage]
    let createdAt: Date
    let updatedAt: Date
    let model: String
    let provider: String

    var messageCount: Int { messages.count }
    var duration: TimeInterval { updatedAt.timeIntervalSince(createdAt) }
}

// MARK: - Tests: MigrationStage

@Suite("Migration Stage")
struct MigrationStageTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestMigrationStage.allCases.count == 7)
    }

    @Test("Only complete is complete")
    func onlyCompleteIsComplete() {
        for stage in TestMigrationStage.allCases {
            if stage == .complete {
                #expect(stage.isComplete)
            } else {
                #expect(!stage.isComplete)
            }
        }
    }

    @Test("Stages are in order")
    func stageOrdering() {
        let stages = TestMigrationStage.allCases.sorted { $0.order < $1.order }
        #expect(stages.first == .scanning)
        #expect(stages.last == .complete)
    }

    @Test("Orders are sequential")
    func sequentialOrders() {
        let orders = TestMigrationStage.allCases.map(\.order).sorted()
        for i in 0..<orders.count {
            #expect(orders[i] == i)
        }
    }

    @Test("Orders are unique")
    func uniqueOrders() {
        let orders = Set(TestMigrationStage.allCases.map(\.order))
        #expect(orders.count == TestMigrationStage.allCases.count)
    }
}

// MARK: - Tests: MigrationOptions

@Suite("Migration Options")
struct MigrationOptionsTests {
    @Test("Default options enable everything")
    func defaults() {
        let options = TestMigrationOptions()
        #expect(options.includeConversations)
        #expect(options.includeProjects)
        #expect(options.includeSettings)
        #expect(options.includeAttachments)
        #expect(options.deduplicateConversations)
    }

    @Test("Custom options")
    func custom() {
        let options = TestMigrationOptions(includeConversations: true, includeProjects: false, includeSettings: false, includeAttachments: false, deduplicateConversations: false)
        #expect(options.includeConversations)
        #expect(!options.includeProjects)
        #expect(!options.includeSettings)
        #expect(!options.deduplicateConversations)
    }
}

// MARK: - Tests: MigrationEstimate

@Suite("Migration Estimate")
struct MigrationEstimateTests {
    @Test("Formatted size: bytes")
    func formatBytes() {
        let estimate = TestMigrationEstimate(conversationCount: 1, projectCount: 0, attachmentCount: 0, totalSizeBytes: 512, estimatedDurationSeconds: 1)
        #expect(estimate.formattedSize == "512 bytes")
    }

    @Test("Formatted size: KB")
    func formatKB() {
        let estimate = TestMigrationEstimate(conversationCount: 10, projectCount: 0, attachmentCount: 0, totalSizeBytes: 10240, estimatedDurationSeconds: 2)
        #expect(estimate.formattedSize == "10.0 KB")
    }

    @Test("Formatted size: MB")
    func formatMB() {
        let estimate = TestMigrationEstimate(conversationCount: 100, projectCount: 5, attachmentCount: 10, totalSizeBytes: 5_242_880, estimatedDurationSeconds: 10)
        #expect(estimate.formattedSize == "5.0 MB")
    }

    @Test("Formatted size: GB")
    func formatGB() {
        let estimate = TestMigrationEstimate(conversationCount: 1000, projectCount: 50, attachmentCount: 500, totalSizeBytes: 2_147_483_648, estimatedDurationSeconds: 300)
        #expect(estimate.formattedSize == "2.0 GB")
    }

    @Test("Total items")
    func totalItems() {
        let estimate = TestMigrationEstimate(conversationCount: 50, projectCount: 10, attachmentCount: 25, totalSizeBytes: 1000, estimatedDurationSeconds: 5)
        #expect(estimate.totalItems == 85)
    }
}

// MARK: - Tests: MigrationProgress

@Suite("Migration Progress")
struct MigrationProgressTests {
    @Test("Percentage: zero total")
    func zeroTotal() {
        let progress = TestMigrationProgress(stage: .scanning, currentItem: "", itemsProcessed: 0, totalItems: 0)
        #expect(progress.percentage == 0)
    }

    @Test("Percentage: partial")
    func partial() {
        let progress = TestMigrationProgress(stage: .conversations, currentItem: "Chat 5", itemsProcessed: 5, totalItems: 10)
        #expect(progress.percentage == 50)
    }

    @Test("Percentage: complete")
    func complete() {
        let progress = TestMigrationProgress(stage: .complete, currentItem: "", itemsProcessed: 100, totalItems: 100)
        #expect(progress.percentage == 100)
    }

    @Test("Percentage: capped at 100")
    func capped() {
        let progress = TestMigrationProgress(stage: .finalizing, currentItem: "", itemsProcessed: 150, totalItems: 100)
        #expect(progress.percentage == 100)
    }
}

// MARK: - Tests: MigrationStats

@Suite("Migration Stats")
struct MigrationStatsTests {
    @Test("Default stats are zero")
    func defaults() {
        let stats = TestMigrationStats()
        #expect(stats.totalItems == 0)
    }

    @Test("Total items aggregation")
    func totalItems() {
        let stats = TestMigrationStats(conversationCount: 10, messageCount: 100, projectCount: 5, attachmentCount: 20)
        #expect(stats.totalItems == 135)
    }
}

// MARK: - Tests: MigrationStatus

@Suite("Migration Status")
struct MigrationStatusTests {
    @Test("Running is not terminal")
    func runningNotTerminal() {
        let status = TestMigrationStatus.running
        #expect(!status.isTerminal)
    }

    @Test("Completed is terminal")
    func completedTerminal() {
        let status = TestMigrationStatus.completed
        #expect(status.isTerminal)
    }

    @Test("Failed is terminal")
    func failedTerminal() {
        let status = TestMigrationStatus.failed("error")
        #expect(status.isTerminal)
    }
}

// MARK: - Tests: MigrationError

@Suite("Migration Error")
struct MigrationErrorTests {
    @Test("All errors have descriptions")
    func allDescriptions() {
        let errors: [TestMigrationError] = [.manualExportRequired, .webBasedApp, .notImplemented, .noModelContext]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }

    @Test("Descriptions are unique")
    func uniqueDescriptions() {
        let errors: [TestMigrationError] = [.manualExportRequired, .webBasedApp, .notImplemented, .noModelContext]
        let descs = Set(errors.compactMap(\.errorDescription))
        #expect(descs.count == errors.count)
    }
}

// MARK: - Tests: MigrationSourceInfo

@Suite("Migration Source Info")
struct MigrationSourceInfoTests {
    @Test("All sources have non-empty names")
    func names() {
        for source in TestMigrationSourceInfo.allSources {
            #expect(!source.sourceName.isEmpty)
        }
    }

    @Test("All sources have non-empty icons")
    func icons() {
        for source in TestMigrationSourceInfo.allSources {
            #expect(!source.sourceIcon.isEmpty)
        }
    }

    @Test("All sources have descriptions")
    func descriptions() {
        for source in TestMigrationSourceInfo.allSources {
            #expect(!source.sourceDescription.isEmpty)
        }
    }

    @Test("Source count is 5")
    func sourceCount() {
        #expect(TestMigrationSourceInfo.allSources.count == 5)
    }

    @Test("Source names are unique")
    func uniqueNames() {
        let names = Set(TestMigrationSourceInfo.allSources.map(\.sourceName))
        #expect(names.count == TestMigrationSourceInfo.allSources.count)
    }

    @Test("Installed sources subset")
    func installedSources() {
        let installed = TestMigrationSourceInfo.allSources.filter(\.isInstalled)
        #expect(installed.count >= 1)
        #expect(installed.count <= TestMigrationSourceInfo.allSources.count)
    }
}

// MARK: - Tests: MigratedConversation

@Suite("Migrated Conversation")
struct MigratedConversationTests {
    @Test("Message count")
    func messageCount() {
        let now = Date()
        let messages = [
            TestMigratedMessage(role: .user, content: .text("Hello"), timestamp: now),
            TestMigratedMessage(role: .assistant, content: .text("Hi!"), timestamp: now.addingTimeInterval(1))
        ]
        let convo = TestMigratedConversation(title: "Test", messages: messages, createdAt: now, updatedAt: now.addingTimeInterval(2), model: "claude-4.5-sonnet", provider: "anthropic")
        #expect(convo.messageCount == 2)
    }

    @Test("Duration calculation")
    func duration() {
        let start = Date()
        let end = start.addingTimeInterval(3600) // 1 hour
        let convo = TestMigratedConversation(title: "Long Chat", messages: [], createdAt: start, updatedAt: end, model: "gpt-4o", provider: "openai")
        #expect(convo.duration == 3600)
    }

    @Test("Empty conversation")
    func emptyConvo() {
        let now = Date()
        let convo = TestMigratedConversation(title: "Empty", messages: [], createdAt: now, updatedAt: now, model: "test", provider: "test")
        #expect(convo.messageCount == 0)
        #expect(convo.duration == 0)
    }
}

// MARK: - Tests: MigratedMessage

@Suite("Migrated Message")
struct MigratedMessageTests {
    @Test("User message")
    func userMessage() {
        let msg = TestMigratedMessage(role: .user, content: .text("Hello"), timestamp: Date())
        #expect(msg.role == .user)
    }

    @Test("Assistant message")
    func assistantMessage() {
        let msg = TestMigratedMessage(role: .assistant, content: .text("Hi there!"), timestamp: Date())
        #expect(msg.role == .assistant)
    }

    @Test("System message")
    func systemMessage() {
        let msg = TestMigratedMessage(role: .system, content: .text("You are a helpful assistant."), timestamp: Date())
        #expect(msg.role == .system)
    }

    @Test("Multipart content")
    func multipartContent() {
        let msg = TestMigratedMessage(role: .user, content: .multipart(["text part", "image part"]), timestamp: Date())
        if case .multipart(let parts) = msg.content {
            #expect(parts.count == 2)
        } else {
            Issue.record("Expected multipart content")
        }
    }

    @Test("Text content extraction")
    func textContent() {
        let msg = TestMigratedMessage(role: .user, content: .text("Hello world"), timestamp: Date())
        if case .text(let text) = msg.content {
            #expect(text == "Hello world")
        } else {
            Issue.record("Expected text content")
        }
    }
}

// MARK: - Tests: TrackerType (from TrackingCoordinator)

private enum TestTrackerType: String, Codable, Sendable, CaseIterable {
    case location, health, usage, browser, input

    var displayName: String {
        switch self {
        case .location: return "Location"
        case .health: return "Health"
        case .usage: return "App Usage"
        case .browser: return "Browser"
        case .input: return "Input"
        }
    }

    var privacyDescription: String {
        switch self {
        case .location: return "Tracks your geographic location"
        case .health: return "Monitors health and fitness data"
        case .usage: return "Tracks app usage patterns"
        case .browser: return "Monitors browser history"
        case .input: return "Tracks keyboard and mouse activity"
        }
    }
}

@Suite("Tracker Type")
struct TrackerTypeTests {
    @Test("All cases exist")
    func allCases() {
        #expect(TestTrackerType.allCases.count == 5)
    }

    @Test("Display names are non-empty and unique")
    func displayNames() {
        let names = Set(TestTrackerType.allCases.map(\.displayName))
        #expect(names.count == TestTrackerType.allCases.count)
        for name in names {
            #expect(!name.isEmpty)
        }
    }

    @Test("Privacy descriptions are non-empty")
    func privacyDescriptions() {
        for tracker in TestTrackerType.allCases {
            #expect(!tracker.privacyDescription.isEmpty)
        }
    }

    @Test("Codable roundtrip")
    func codable() throws {
        for tracker in TestTrackerType.allCases {
            let data = try JSONEncoder().encode(tracker)
            let decoded = try JSONDecoder().decode(TestTrackerType.self, from: data)
            #expect(decoded == tracker)
        }
    }
}

// MARK: - Tests: TrackingEvent

private struct TestTrackingEvent: Identifiable, Codable, Sendable {
    let id: UUID
    let type: TestTrackerType
    let timestamp: Date
    let data: [String: String]

    init(type: TestTrackerType, data: [String: String] = [:]) {
        self.id = UUID()
        self.type = type
        self.timestamp = Date()
        self.data = data
    }
}

@Suite("Tracking Event")
struct TrackingEventTests {
    @Test("Creation with auto-generated ID")
    func creation() {
        let event = TestTrackingEvent(type: .location, data: ["lat": "46.2", "lon": "6.1"])
        #expect(event.type == .location)
        #expect(event.data["lat"] == "46.2")
    }

    @Test("Events have unique IDs")
    func uniqueIds() {
        let e1 = TestTrackingEvent(type: .browser)
        let e2 = TestTrackingEvent(type: .browser)
        #expect(e1.id != e2.id)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let event = TestTrackingEvent(type: .health, data: ["steps": "5000"])
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(TestTrackingEvent.self, from: data)
        #expect(decoded.type == .health)
        #expect(decoded.data["steps"] == "5000")
    }
}
