// BackgroundServiceMonitorTests.swift
// Tests for BackgroundServiceMonitor data types and logic

import Testing
import Foundation

// MARK: - Test Doubles

private enum TestServiceStatus: String, CaseIterable {
    case healthy
    case degraded
    case unhealthy
    case unknown
    case recovering

    var icon: String {
        switch self {
        case .healthy: "checkmark.circle.fill"
        case .degraded: "exclamationmark.triangle.fill"
        case .unhealthy: "xmark.circle.fill"
        case .unknown: "questionmark.circle.fill"
        case .recovering: "arrow.triangle.2.circlepath"
        }
    }

    var priority: Int {
        switch self {
        case .unhealthy: 0
        case .recovering: 1
        case .degraded: 2
        case .unknown: 3
        case .healthy: 4
        }
    }
}

private enum TestServiceCategory: String, CaseIterable {
    case sync
    case aiProvider
    case system
    case integration
    case privacy

    var displayName: String {
        switch self {
        case .sync: "Sync & Transport"
        case .aiProvider: "AI Providers"
        case .system: "System Resources"
        case .integration: "Integrations"
        case .privacy: "Privacy & Security"
        }
    }

    var icon: String {
        switch self {
        case .sync: "arrow.triangle.2.circlepath"
        case .aiProvider: "brain"
        case .system: "cpu"
        case .integration: "puzzlepiece"
        case .privacy: "lock.shield"
        }
    }
}

private struct TestCheckResult: Codable, Sendable, Identifiable {
    let id: UUID
    let serviceID: String
    let serviceName: String
    let category: String
    let status: String
    let message: String
    let latencyMs: Double?
    let timestamp: Date
    let recoveryAttempted: Bool
    let recoverySucceeded: Bool?

    init(
        serviceID: String,
        serviceName: String,
        category: String = "system",
        status: String,
        message: String,
        latencyMs: Double? = nil,
        recoveryAttempted: Bool = false,
        recoverySucceeded: Bool? = nil
    ) {
        self.id = UUID()
        self.serviceID = serviceID
        self.serviceName = serviceName
        self.category = category
        self.status = status
        self.message = message
        self.latencyMs = latencyMs
        self.timestamp = Date()
        self.recoveryAttempted = recoveryAttempted
        self.recoverySucceeded = recoverySucceeded
    }
}

private struct TestRecoveryAction: Codable, Sendable, Identifiable {
    let id: UUID
    let serviceID: String
    let actionName: String
    let description: String
    let timestamp: Date
    let succeeded: Bool
    let errorMessage: String?

    init(
        serviceID: String,
        actionName: String,
        description: String,
        succeeded: Bool,
        errorMessage: String? = nil
    ) {
        self.id = UUID()
        self.serviceID = serviceID
        self.actionName = actionName
        self.description = description
        self.timestamp = Date()
        self.succeeded = succeeded
        self.errorMessage = errorMessage
    }
}

private struct TestHealthSnapshot: Codable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let checks: [TestCheckResult]
    let overallStatus: String
    let healthyCount: Int
    let degradedCount: Int
    let unhealthyCount: Int
    let recoveryCount: Int

    init(checks: [TestCheckResult]) {
        self.id = UUID()
        self.timestamp = Date()
        self.checks = checks
        self.healthyCount = checks.filter { $0.status == "healthy" }.count
        self.degradedCount = checks.filter { $0.status == "degraded" }.count
        self.unhealthyCount = checks.filter { $0.status == "unhealthy" }.count
        self.recoveryCount = checks.filter { $0.status == "recovering" }.count

        if unhealthyCount > 0 {
            self.overallStatus = "unhealthy"
        } else if degradedCount > 0 || recoveryCount > 0 {
            self.overallStatus = "degraded"
        } else if healthyCount > 0 {
            self.overallStatus = "healthy"
        } else {
            self.overallStatus = "unknown"
        }
    }
}

// MARK: - TheaServiceStatus Tests

@Suite("BackgroundServiceMonitor — ServiceStatus")
struct ServiceStatusTests {
    @Test("All 5 status cases exist")
    func allCases() {
        #expect(TestServiceStatus.allCases.count == 5)
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestServiceStatus.allCases.map(\.rawValue))
        #expect(rawValues.count == 5)
    }

    @Test("Each status has an SF Symbol icon")
    func icons() {
        for status in TestServiceStatus.allCases {
            #expect(!status.icon.isEmpty)
        }
    }

    @Test("Healthy icon is checkmark.circle.fill")
    func healthyIcon() {
        #expect(TestServiceStatus.healthy.icon == "checkmark.circle.fill")
    }

    @Test("Unhealthy icon is xmark.circle.fill")
    func unhealthyIcon() {
        #expect(TestServiceStatus.unhealthy.icon == "xmark.circle.fill")
    }

    @Test("Priority: unhealthy (0) < recovering (1) < degraded (2) < unknown (3) < healthy (4)")
    func priorityOrdering() {
        #expect(TestServiceStatus.unhealthy.priority == 0)
        #expect(TestServiceStatus.recovering.priority == 1)
        #expect(TestServiceStatus.degraded.priority == 2)
        #expect(TestServiceStatus.unknown.priority == 3)
        #expect(TestServiceStatus.healthy.priority == 4)
    }

    @Test("Unhealthy has lowest (most urgent) priority")
    func unhealthyMostUrgent() {
        let sorted = TestServiceStatus.allCases.sorted { $0.priority < $1.priority }
        #expect(sorted.first == .unhealthy)
    }

    @Test("Healthy has highest (least urgent) priority")
    func healthyLeastUrgent() {
        let sorted = TestServiceStatus.allCases.sorted { $0.priority < $1.priority }
        #expect(sorted.last == .healthy)
    }
}

// MARK: - TheaServiceCategory Tests

@Suite("BackgroundServiceMonitor — ServiceCategory")
struct ServiceCategoryTests {
    @Test("All 5 category cases exist")
    func allCases() {
        #expect(TestServiceCategory.allCases.count == 5)
    }

    @Test("Unique raw values")
    func uniqueRawValues() {
        let rawValues = Set(TestServiceCategory.allCases.map(\.rawValue))
        #expect(rawValues.count == 5)
    }

    @Test("Each category has a display name")
    func displayNames() {
        for category in TestServiceCategory.allCases {
            #expect(!category.displayName.isEmpty)
        }
    }

    @Test("Display names are human-readable")
    func humanReadableDisplayNames() {
        #expect(TestServiceCategory.sync.displayName == "Sync & Transport")
        #expect(TestServiceCategory.aiProvider.displayName == "AI Providers")
        #expect(TestServiceCategory.system.displayName == "System Resources")
        #expect(TestServiceCategory.integration.displayName == "Integrations")
        #expect(TestServiceCategory.privacy.displayName == "Privacy & Security")
    }

    @Test("Each category has an SF Symbol icon")
    func icons() {
        for category in TestServiceCategory.allCases {
            #expect(!category.icon.isEmpty)
        }
    }

    @Test("Unique icons across categories")
    func uniqueIcons() {
        let icons = Set(TestServiceCategory.allCases.map(\.icon))
        #expect(icons.count == 5)
    }
}

// MARK: - CheckResult Tests

@Suite("BackgroundServiceMonitor — CheckResult")
struct CheckResultTests {
    @Test("Default construction")
    func defaultConstruction() {
        let result = TestCheckResult(
            serviceID: "test_service",
            serviceName: "Test Service",
            status: "healthy",
            message: "All good"
        )
        #expect(result.serviceID == "test_service")
        #expect(result.serviceName == "Test Service")
        #expect(result.status == "healthy")
        #expect(result.message == "All good")
        #expect(result.latencyMs == nil)
        #expect(!result.recoveryAttempted)
        #expect(result.recoverySucceeded == nil)
    }

    @Test("Construction with all parameters")
    func fullConstruction() {
        let result = TestCheckResult(
            serviceID: "api",
            serviceName: "API Provider",
            category: "aiProvider",
            status: "degraded",
            message: "Slow response",
            latencyMs: 250.5,
            recoveryAttempted: true,
            recoverySucceeded: true
        )
        #expect(result.serviceID == "api")
        #expect(result.category == "aiProvider")
        #expect(result.latencyMs == 250.5)
        #expect(result.recoveryAttempted)
        #expect(result.recoverySucceeded == true)
    }

    @Test("Identifiable — unique IDs")
    func uniqueIDs() {
        let r1 = TestCheckResult(serviceID: "a", serviceName: "A", status: "healthy", message: "ok")
        let r2 = TestCheckResult(serviceID: "a", serviceName: "A", status: "healthy", message: "ok")
        #expect(r1.id != r2.id)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let original = TestCheckResult(
            serviceID: "test",
            serviceName: "Test",
            status: "unhealthy",
            message: "down",
            latencyMs: 100,
            recoveryAttempted: true,
            recoverySucceeded: false
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TestCheckResult.self, from: data)
        #expect(decoded.serviceID == original.serviceID)
        #expect(decoded.status == original.status)
        #expect(decoded.message == original.message)
        #expect(decoded.latencyMs == original.latencyMs)
        #expect(decoded.recoveryAttempted == original.recoveryAttempted)
        #expect(decoded.recoverySucceeded == original.recoverySucceeded)
    }

    @Test("Timestamp is set to now")
    func timestampIsNow() {
        let before = Date()
        let result = TestCheckResult(serviceID: "a", serviceName: "A", status: "healthy", message: "ok")
        let after = Date()
        #expect(result.timestamp >= before)
        #expect(result.timestamp <= after)
    }
}

// MARK: - RecoveryAction Tests

@Suite("BackgroundServiceMonitor — RecoveryAction")
struct RecoveryActionTests {
    @Test("Successful recovery")
    func successfulRecovery() {
        let action = TestRecoveryAction(
            serviceID: "cloudkit_sync",
            actionName: "force-sync",
            description: "Auto-recovery for CloudKit Sync",
            succeeded: true
        )
        #expect(action.serviceID == "cloudkit_sync")
        #expect(action.actionName == "force-sync")
        #expect(action.succeeded)
        #expect(action.errorMessage == nil)
    }

    @Test("Failed recovery with error message")
    func failedRecovery() {
        let action = TestRecoveryAction(
            serviceID: "disk_space",
            actionName: "suggest-cleanup",
            description: "Auto-recovery for Disk Space",
            succeeded: false,
            errorMessage: "Low disk space requires user action"
        )
        #expect(!action.succeeded)
        #expect(action.errorMessage == "Low disk space requires user action")
    }

    @Test("Identifiable — unique IDs")
    func uniqueIDs() {
        let a1 = TestRecoveryAction(serviceID: "a", actionName: "x", description: "d", succeeded: true)
        let a2 = TestRecoveryAction(serviceID: "a", actionName: "x", description: "d", succeeded: true)
        #expect(a1.id != a2.id)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let original = TestRecoveryAction(
            serviceID: "test",
            actionName: "restart",
            description: "Recovery",
            succeeded: false,
            errorMessage: "Timeout"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TestRecoveryAction.self, from: data)
        #expect(decoded.serviceID == original.serviceID)
        #expect(decoded.actionName == original.actionName)
        #expect(decoded.succeeded == original.succeeded)
        #expect(decoded.errorMessage == original.errorMessage)
    }

    @Test("Timestamp is set on creation")
    func hasTimestamp() {
        let action = TestRecoveryAction(serviceID: "a", actionName: "b", description: "c", succeeded: true)
        #expect(abs(action.timestamp.timeIntervalSinceNow) < 1)
    }
}

// MARK: - HealthSnapshot Tests

@Suite("BackgroundServiceMonitor — HealthSnapshot")
struct HealthSnapshotTests {
    @Test("All healthy → overall healthy")
    func allHealthy() {
        let checks = [
            TestCheckResult(serviceID: "a", serviceName: "A", status: "healthy", message: "ok"),
            TestCheckResult(serviceID: "b", serviceName: "B", status: "healthy", message: "ok"),
            TestCheckResult(serviceID: "c", serviceName: "C", status: "healthy", message: "ok")
        ]
        let snapshot = TestHealthSnapshot(checks: checks)
        #expect(snapshot.overallStatus == "healthy")
        #expect(snapshot.healthyCount == 3)
        #expect(snapshot.degradedCount == 0)
        #expect(snapshot.unhealthyCount == 0)
        #expect(snapshot.recoveryCount == 0)
    }

    @Test("One degraded → overall degraded")
    func oneDegraded() {
        let checks = [
            TestCheckResult(serviceID: "a", serviceName: "A", status: "healthy", message: "ok"),
            TestCheckResult(serviceID: "b", serviceName: "B", status: "degraded", message: "slow"),
            TestCheckResult(serviceID: "c", serviceName: "C", status: "healthy", message: "ok")
        ]
        let snapshot = TestHealthSnapshot(checks: checks)
        #expect(snapshot.overallStatus == "degraded")
        #expect(snapshot.healthyCount == 2)
        #expect(snapshot.degradedCount == 1)
    }

    @Test("One unhealthy → overall unhealthy (overrides degraded)")
    func oneUnhealthy() {
        let checks = [
            TestCheckResult(serviceID: "a", serviceName: "A", status: "healthy", message: "ok"),
            TestCheckResult(serviceID: "b", serviceName: "B", status: "degraded", message: "slow"),
            TestCheckResult(serviceID: "c", serviceName: "C", status: "unhealthy", message: "down")
        ]
        let snapshot = TestHealthSnapshot(checks: checks)
        #expect(snapshot.overallStatus == "unhealthy")
        #expect(snapshot.unhealthyCount == 1)
    }

    @Test("Recovering → overall degraded")
    func recovering() {
        let checks = [
            TestCheckResult(serviceID: "a", serviceName: "A", status: "healthy", message: "ok"),
            TestCheckResult(serviceID: "b", serviceName: "B", status: "recovering", message: "retrying")
        ]
        let snapshot = TestHealthSnapshot(checks: checks)
        #expect(snapshot.overallStatus == "degraded")
        #expect(snapshot.recoveryCount == 1)
    }

    @Test("Empty checks → overall unknown")
    func emptyChecks() {
        let snapshot = TestHealthSnapshot(checks: [])
        #expect(snapshot.overallStatus == "unknown")
        #expect(snapshot.healthyCount == 0)
        #expect(snapshot.degradedCount == 0)
        #expect(snapshot.unhealthyCount == 0)
    }

    @Test("All unknown → overall unknown")
    func allUnknown() {
        let checks = [
            TestCheckResult(serviceID: "a", serviceName: "A", status: "unknown", message: "disabled")
        ]
        let snapshot = TestHealthSnapshot(checks: checks)
        #expect(snapshot.overallStatus == "unknown")
    }

    @Test("Identifiable — unique IDs")
    func uniqueIDs() {
        let s1 = TestHealthSnapshot(checks: [])
        let s2 = TestHealthSnapshot(checks: [])
        #expect(s1.id != s2.id)
    }

    @Test("Timestamp is set on creation")
    func hasTimestamp() {
        let snapshot = TestHealthSnapshot(checks: [])
        #expect(abs(snapshot.timestamp.timeIntervalSinceNow) < 1)
    }

    @Test("Counts are accurate with mixed statuses")
    func mixedCounts() {
        let checks = [
            TestCheckResult(serviceID: "a", serviceName: "A", status: "healthy", message: ""),
            TestCheckResult(serviceID: "b", serviceName: "B", status: "healthy", message: ""),
            TestCheckResult(serviceID: "c", serviceName: "C", status: "degraded", message: ""),
            TestCheckResult(serviceID: "d", serviceName: "D", status: "unhealthy", message: ""),
            TestCheckResult(serviceID: "e", serviceName: "E", status: "recovering", message: ""),
            TestCheckResult(serviceID: "f", serviceName: "F", status: "unknown", message: "")
        ]
        let snapshot = TestHealthSnapshot(checks: checks)
        #expect(snapshot.healthyCount == 2)
        #expect(snapshot.degradedCount == 1)
        #expect(snapshot.unhealthyCount == 1)
        #expect(snapshot.recoveryCount == 1)
        #expect(snapshot.checks.count == 6)
    }

    @Test("Codable roundtrip")
    func codable() throws {
        let checks = [
            TestCheckResult(serviceID: "a", serviceName: "A", status: "healthy", message: "ok")
        ]
        let original = TestHealthSnapshot(checks: checks)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TestHealthSnapshot.self, from: data)
        #expect(decoded.overallStatus == original.overallStatus)
        #expect(decoded.healthyCount == original.healthyCount)
        #expect(decoded.checks.count == original.checks.count)
    }
}

// MARK: - Consecutive Failure Tracking Logic

@Suite("BackgroundServiceMonitor — Failure Tracking")
struct FailureTrackingTests {
    @Test("Increment consecutive failures")
    func incrementFailures() {
        var failures: [String: Int] = [:]
        let serviceID = "cloudkit_sync"

        // Simulate 3 unhealthy checks
        for _ in 1...3 {
            let count = (failures[serviceID] ?? 0) + 1
            failures[serviceID] = count
        }

        #expect(failures[serviceID] == 3)
    }

    @Test("Reset failure count on healthy check")
    func resetOnHealthy() {
        var failures: [String: Int] = ["cloudkit_sync": 5]
        failures.removeValue(forKey: "cloudkit_sync")
        #expect(failures["cloudkit_sync"] == nil)
    }

    @Test("Multiple services tracked independently")
    func independentTracking() {
        var failures: [String: Int] = [:]
        failures["sync"] = 3
        failures["ai"] = 1
        failures["disk"] = 5

        #expect(failures["sync"] == 3)
        #expect(failures["ai"] == 1)
        #expect(failures["disk"] == 5)
    }

    @Test("Recovery triggered at threshold (3)")
    func recoveryThreshold() {
        let maxFailures = 3
        var failures: [String: Int] = [:]
        let serviceID = "test"

        var recoveryTriggered = false
        for _ in 1...3 {
            let count = (failures[serviceID] ?? 0) + 1
            failures[serviceID] = count
            if count >= maxFailures {
                recoveryTriggered = true
            }
        }
        #expect(recoveryTriggered)
    }

    @Test("No recovery before threshold")
    func noRecoveryBeforeThreshold() {
        let maxFailures = 3
        var failures: [String: Int] = [:]
        let serviceID = "test"

        var recoveryTriggered = false
        for _ in 1...2 {
            let count = (failures[serviceID] ?? 0) + 1
            failures[serviceID] = count
            if count >= maxFailures {
                recoveryTriggered = true
            }
        }
        #expect(!recoveryTriggered)
    }
}

// MARK: - Recovery History Management

@Suite("BackgroundServiceMonitor — Recovery History")
struct RecoveryHistoryTests {
    @Test("Append to history")
    func appendHistory() {
        var history: [TestRecoveryAction] = []
        let action = TestRecoveryAction(serviceID: "a", actionName: "restart", description: "d", succeeded: true)
        history.append(action)
        #expect(history.count == 1)
    }

    @Test("Cap history at max (100)")
    func capHistory() {
        let maxHistory = 100
        var history: [TestRecoveryAction] = []
        for i in 0..<120 {
            let action = TestRecoveryAction(serviceID: "s\(i)", actionName: "a", description: "d", succeeded: true)
            history.append(action)
            if history.count > maxHistory {
                history = Array(history.suffix(maxHistory))
            }
        }
        #expect(history.count == maxHistory)
    }

    @Test("Recent recoveries returns last 10")
    func recentRecoveries() {
        var history: [TestRecoveryAction] = []
        for i in 0..<25 {
            let action = TestRecoveryAction(serviceID: "s\(i)", actionName: "a", description: "d", succeeded: i.isMultiple(of: 2))
            history.append(action)
        }
        let recent = Array(history.suffix(10))
        #expect(recent.count == 10)
        #expect(recent.first?.serviceID == "s15")
        #expect(recent.last?.serviceID == "s24")
    }

    @Test("Empty history returns empty recent")
    func emptyHistory() {
        let history: [TestRecoveryAction] = []
        let recent = Array(history.suffix(10))
        #expect(recent.isEmpty)
    }
}

// MARK: - Snapshot History Management

@Suite("BackgroundServiceMonitor — Snapshot History")
struct SnapshotHistoryTests {
    @Test("Cap snapshot history at max (720)")
    func capSnapshotHistory() {
        let maxHistory = 720
        var history: [TestHealthSnapshot] = []
        for _ in 0..<730 {
            let snapshot = TestHealthSnapshot(checks: [])
            history.append(snapshot)
            if history.count > maxHistory {
                history = Array(history.suffix(maxHistory))
            }
        }
        #expect(history.count == maxHistory)
    }

    @Test("Latest snapshot is the most recent")
    func latestSnapshot() {
        var history: [TestHealthSnapshot] = []
        let s1 = TestHealthSnapshot(checks: [
            TestCheckResult(serviceID: "a", serviceName: "A", status: "healthy", message: "ok")
        ])
        let s2 = TestHealthSnapshot(checks: [
            TestCheckResult(serviceID: "b", serviceName: "B", status: "unhealthy", message: "down")
        ])
        history.append(s1)
        history.append(s2)
        let latest = history.last
        #expect(latest?.overallStatus == "unhealthy")
    }
}

// MARK: - Statistics Logic

@Suite("BackgroundServiceMonitor — Statistics")
struct StatisticsTests {
    @Test("Healthy percentage — all healthy")
    func allHealthyPercentage() {
        let checks = [
            TestCheckResult(serviceID: "a", serviceName: "A", status: "healthy", message: ""),
            TestCheckResult(serviceID: "b", serviceName: "B", status: "healthy", message: "")
        ]
        let snapshot = TestHealthSnapshot(checks: checks)
        let percentage = Double(snapshot.healthyCount) / Double(snapshot.checks.count) * 100
        #expect(percentage == 100.0)
    }

    @Test("Healthy percentage — mixed")
    func mixedPercentage() {
        let checks = [
            TestCheckResult(serviceID: "a", serviceName: "A", status: "healthy", message: ""),
            TestCheckResult(serviceID: "b", serviceName: "B", status: "degraded", message: ""),
            TestCheckResult(serviceID: "c", serviceName: "C", status: "unhealthy", message: ""),
            TestCheckResult(serviceID: "d", serviceName: "D", status: "healthy", message: "")
        ]
        let snapshot = TestHealthSnapshot(checks: checks)
        let percentage = Double(snapshot.healthyCount) / Double(snapshot.checks.count) * 100
        #expect(percentage == 50.0)
    }

    @Test("Healthy percentage — empty returns 0")
    func emptyPercentage() {
        let snapshot = TestHealthSnapshot(checks: [])
        let percentage: Double = snapshot.checks.isEmpty ? 0 : Double(snapshot.healthyCount) / Double(snapshot.checks.count) * 100
        #expect(percentage == 0)
    }

    @Test("Services grouped by category")
    func groupByCategory() {
        let checks = [
            TestCheckResult(serviceID: "sync1", serviceName: "Sync1", category: "sync", status: "healthy", message: ""),
            TestCheckResult(serviceID: "sync2", serviceName: "Sync2", category: "sync", status: "degraded", message: ""),
            TestCheckResult(serviceID: "ai1", serviceName: "AI", category: "aiProvider", status: "healthy", message: ""),
            TestCheckResult(serviceID: "sys1", serviceName: "Sys", category: "system", status: "healthy", message: "")
        ]
        let grouped = Dictionary(grouping: checks, by: \.category)
        #expect(grouped["sync"]?.count == 2)
        #expect(grouped["aiProvider"]?.count == 1)
        #expect(grouped["system"]?.count == 1)
        #expect(grouped["privacy"] == nil)
    }
}

// MARK: - Uptime Formatting

@Suite("BackgroundServiceMonitor — Uptime Formatting")
struct UptimeFormattingTests {
    private func formatUptime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 24 {
            return "\(hours / 24)d \(hours % 24)h"
        }
        return "\(hours)h \(minutes)m"
    }

    @Test("Short uptime — minutes only")
    func shortUptime() {
        let result = formatUptime(1800) // 30 minutes
        #expect(result == "0h 30m")
    }

    @Test("Hours and minutes")
    func hoursAndMinutes() {
        let result = formatUptime(7380) // 2h 3m
        #expect(result == "2h 3m")
    }

    @Test("Exactly 24 hours")
    func exactly24Hours() {
        let result = formatUptime(86400) // 24h
        #expect(result == "24h 0m")
    }

    @Test("Over 24 hours — shows days")
    func overOneDay() {
        let result = formatUptime(100000) // ~27.7h
        #expect(result == "1d 3h")
    }

    @Test("Multiple days")
    func multipleDays() {
        let result = formatUptime(259200) // 72h = 3d
        #expect(result == "3d 0h")
    }
}

// MARK: - Sync Interval Logic

@Suite("BackgroundServiceMonitor — Sync Interval Classification")
struct BSMSyncIntervalTests {
    private func classifySyncInterval(_ interval: TimeInterval) -> String {
        if interval < 600 { // Within 10 minutes
            return "healthy"
        } else if interval < 3600 { // Within 1 hour
            return "degraded"
        } else {
            return "unhealthy"
        }
    }

    @Test("Recent sync (< 10 min) is healthy")
    func recentSync() {
        #expect(classifySyncInterval(300) == "healthy")
    }

    @Test("Sync at exactly 10 min is degraded")
    func exactlyTenMinutes() {
        #expect(classifySyncInterval(600) == "degraded")
    }

    @Test("Sync at 30 min is degraded")
    func thirtyMinutes() {
        #expect(classifySyncInterval(1800) == "degraded")
    }

    @Test("Sync at exactly 1 hour is unhealthy")
    func exactlyOneHour() {
        #expect(classifySyncInterval(3600) == "unhealthy")
    }

    @Test("Sync at 24 hours is unhealthy")
    func twentyFourHours() {
        #expect(classifySyncInterval(86400) == "unhealthy")
    }
}

// MARK: - Memory Pressure Classification

@Suite("BackgroundServiceMonitor — Memory Pressure")
struct MemoryPressureTests {
    private func classifyMemoryPressure(_ usedPercent: Double) -> String {
        if usedPercent < 70 {
            return "healthy"
        } else if usedPercent < 85 {
            return "degraded"
        } else {
            return "unhealthy"
        }
    }

    @Test("Low usage is healthy")
    func lowUsage() {
        #expect(classifyMemoryPressure(50) == "healthy")
    }

    @Test("69% is still healthy")
    func justUnderThreshold() {
        #expect(classifyMemoryPressure(69.9) == "healthy")
    }

    @Test("70% is degraded")
    func seventyPercent() {
        #expect(classifyMemoryPressure(70) == "degraded")
    }

    @Test("84% is still degraded")
    func eightyFour() {
        #expect(classifyMemoryPressure(84.9) == "degraded")
    }

    @Test("85% is unhealthy")
    func eightyFive() {
        #expect(classifyMemoryPressure(85) == "unhealthy")
    }

    @Test("99% is unhealthy")
    func ninetyNine() {
        #expect(classifyMemoryPressure(99) == "unhealthy")
    }
}

// MARK: - Disk Space Classification

@Suite("BackgroundServiceMonitor — Disk Space")
struct DiskSpaceTests {
    private func classifyDiskSpace(_ availableGB: Double) -> String {
        if availableGB > 20 {
            return "healthy"
        } else if availableGB > 5 {
            return "degraded"
        } else {
            return "unhealthy"
        }
    }

    @Test("Plenty of space is healthy")
    func plentyOfSpace() {
        #expect(classifyDiskSpace(100) == "healthy")
    }

    @Test("21 GB is healthy")
    func twentyOneGB() {
        #expect(classifyDiskSpace(21) == "healthy")
    }

    @Test("20 GB is degraded")
    func twentyGB() {
        #expect(classifyDiskSpace(20) == "degraded")
    }

    @Test("10 GB is degraded")
    func tenGB() {
        #expect(classifyDiskSpace(10) == "degraded")
    }

    @Test("5 GB is unhealthy")
    func fiveGB() {
        #expect(classifyDiskSpace(5) == "unhealthy")
    }

    @Test("1 GB is unhealthy")
    func oneGB() {
        #expect(classifyDiskSpace(1) == "unhealthy")
    }
}

// MARK: - Persistence Model

@Suite("BackgroundServiceMonitor — Persistence")
struct PersistenceTests {
    private struct SaveableHistory: Codable {
        let snapshots: [TestHealthSnapshot]
        let recoveries: [TestRecoveryAction]
        let consecutiveFailures: [String: Int]
    }

    @Test("Saveable history Codable roundtrip")
    func roundtrip() throws {
        let checks = [
            TestCheckResult(serviceID: "a", serviceName: "A", status: "healthy", message: "ok")
        ]
        let snapshot = TestHealthSnapshot(checks: checks)
        let recovery = TestRecoveryAction(serviceID: "a", actionName: "restart", description: "d", succeeded: true)
        let original = SaveableHistory(
            snapshots: [snapshot],
            recoveries: [recovery],
            consecutiveFailures: ["b": 2]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SaveableHistory.self, from: data)

        #expect(decoded.snapshots.count == 1)
        #expect(decoded.recoveries.count == 1)
        #expect(decoded.consecutiveFailures["b"] == 2)
    }

    @Test("Empty history is Codable")
    func emptyHistory() throws {
        let original = SaveableHistory(snapshots: [], recoveries: [], consecutiveFailures: [:])
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SaveableHistory.self, from: data)
        #expect(decoded.snapshots.isEmpty)
        #expect(decoded.recoveries.isEmpty)
        #expect(decoded.consecutiveFailures.isEmpty)
    }

    @Test("Snapshot history truncation preserves recent")
    func snapshotTruncation() {
        let maxSnapshots = 50
        var snapshots: [TestHealthSnapshot] = []
        for _ in 0..<60 {
            snapshots.append(TestHealthSnapshot(checks: []))
        }
        let saved = Array(snapshots.suffix(maxSnapshots))
        #expect(saved.count == maxSnapshots)
    }
}
