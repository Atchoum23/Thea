//
//  AuditLogService.swift
//  Thea
//
//  Persistent audit logging for remote desktop sessions with export and retention
//

import Foundation
import OSLog

// MARK: - Audit Log Service

/// Persistent audit logging for all remote access actions
@MainActor
public class AuditLogService: ObservableObject {
    // MARK: - Published State

    private let logger = Logger(subsystem: "ai.thea.app", category: "AuditLogService")

    @Published public private(set) var recentEntries: [AuditEntry] = []
    @Published public private(set) var totalEntryCount: Int = 0
    @Published public private(set) var isLogging = true

    // MARK: - Configuration

    public var retentionDays: Int = 90
    public var maxInMemoryEntries: Int = 200

    // MARK: - Storage

    private let storageDirectory: URL
    private let entriesFileURL: URL
    private var allEntries: [AuditEntry] = []

    // MARK: - Initialization

    public init() {
        // Safe: applicationSupportDirectory always returns at least one URL on Apple platforms
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDirectory = appSupport.appendingPathComponent("Thea/AuditLogs", isDirectory: true)
        entriesFileURL = storageDirectory.appendingPathComponent("audit_log.json")
        do {
            try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create audit log directory: \(error.localizedDescription)")
        }
        loadEntries()
        purgeExpiredEntries()
    }

    // MARK: - Log Events

    /// Log a remote access event
    public func log(
        action: AuditAction,
        sessionId: String,
        clientId: String,
        clientName: String,
        details: String = "",
        result: AuditResult = .success
    ) {
        guard isLogging else { return }

        let entry = AuditEntry(
            action: action,
            sessionId: sessionId,
            clientId: clientId,
            clientName: clientName,
            details: details,
            result: result
        )

        allEntries.insert(entry, at: 0)
        recentEntries = Array(allEntries.prefix(maxInMemoryEntries))
        totalEntryCount = allEntries.count

        saveEntries()
    }

    /// Log a security event
    public func logSecurityEvent(
        type: SecurityEventType,
        clientId: String = "",
        clientName: String = "",
        details: String
    ) {
        let action: AuditAction = switch type {
        case .clientConnected: .sessionStarted
        case .clientDisconnected: .sessionEnded
        case .authenticationFailed: .authenticationFailed
        case .connectionRejected: .connectionRejected
        case .permissionDenied: .permissionDenied
        case .rateLimitExceeded: .rateLimitExceeded
        case .suspiciousActivity: .suspiciousActivity
        case .fileAccessBlocked: .fileAccessBlocked
        case .commandBlocked: .commandBlocked
        case .serverStarted: .serverStarted
        case .serverStopped: .serverStopped
        case .serverError: .serverError
        case .totpFailed: .totpFailed
        case .totpVerified: .totpVerified
        case .unattendedAccessUsed: .sessionStarted
        case .privacyModeEnabled: .privacyModeEnabled
        case .privacyModeDisabled: .privacyModeDisabled
        case .recordingStarted: .screenRecordingStarted
        case .recordingStopped: .screenRecordingStopped
        case .clipboardSynced: .clipboardSynced
        case .configurationChanged: .configurationChanged
        }

        log(
            action: action,
            sessionId: "",
            clientId: clientId,
            clientName: clientName,
            details: details,
            result: type == .authenticationFailed || type == .connectionRejected ? .denied : .success
        )
    }

    // MARK: - Query

    /// Get entries filtered by criteria
    public func query(
        action: AuditAction? = nil,
        clientId: String? = nil,
        sessionId: String? = nil,
        from startDate: Date? = nil,
        to endDate: Date? = nil,
        result: AuditResult? = nil,
        limit: Int = 100
    ) -> [AuditEntry] {
        var filtered = allEntries

        if let action {
            filtered = filtered.filter { $0.action == action }
        }
        if let clientId {
            filtered = filtered.filter { $0.clientId == clientId }
        }
        if let sessionId {
            filtered = filtered.filter { $0.sessionId == sessionId }
        }
        if let startDate {
            filtered = filtered.filter { $0.timestamp >= startDate }
        }
        if let endDate {
            filtered = filtered.filter { $0.timestamp <= endDate }
        }
        if let result {
            filtered = filtered.filter { $0.result == result }
        }

        return Array(filtered.prefix(limit))
    }

    /// Search entries by text
    public func search(_ text: String, limit: Int = 100) -> [AuditEntry] {
        let lowered = text.lowercased()
        let filtered = allEntries.filter { entry in
            entry.details.lowercased().contains(lowered)
                || entry.clientName.lowercased().contains(lowered)
                || entry.action.displayName.lowercased().contains(lowered)
        }
        return Array(filtered.prefix(limit))
    }

    // MARK: - Export

    /// Export audit log as CSV
    public func exportAsCSV() -> String {
        var csv = "Timestamp,Action,Session ID,Client ID,Client Name,Details,Result\n"

        let formatter = ISO8601DateFormatter()

        for entry in allEntries {
            let fields = [
                formatter.string(from: entry.timestamp),
                entry.action.rawValue,
                entry.sessionId,
                entry.clientId,
                escapeCSV(entry.clientName),
                escapeCSV(entry.details),
                entry.result.rawValue
            ]
            csv += fields.joined(separator: ",") + "\n"
        }

        return csv
    }

    /// Export audit log as JSON
    public func exportAsJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            return try encoder.encode(allEntries)
        } catch {
            logger.error("Failed to encode audit log as JSON: \(error.localizedDescription)")
            return nil
        }
    }

    /// Save export to file
    public func saveExport(format: ExportFormat) -> URL? {
        let dateStr = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename: String
        let data: Data?

        switch format {
        case .csv:
            filename = "thea_audit_\(dateStr).csv"
            data = exportAsCSV().data(using: .utf8)
        case .json:
            filename = "thea_audit_\(dateStr).json"
            data = exportAsJSON()
        }

        guard let data else { return nil }

        let fileURL = storageDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL)
        } catch {
            logger.error("Failed to write audit export to \(fileURL.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
        return fileURL
    }

    // MARK: - Maintenance

    /// Purge entries older than retention period
    public func purgeExpiredEntries() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        allEntries.removeAll { $0.timestamp < cutoff }
        recentEntries = Array(allEntries.prefix(maxInMemoryEntries))
        totalEntryCount = allEntries.count
        saveEntries()
    }

    /// Clear all audit entries
    public func clearAll() {
        allEntries.removeAll()
        recentEntries.removeAll()
        totalEntryCount = 0
        saveEntries()
    }

    /// Get statistics
    public var statistics: AuditStatistics {
        let now = Date()
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now

        let last24h = allEntries.filter { $0.timestamp >= oneDayAgo }
        let lastWeek = allEntries.filter { $0.timestamp >= oneWeekAgo }

        let failedAuth = allEntries.filter { $0.action == .authenticationFailed }.count
        let blockedActions = allEntries.filter { $0.result == .denied || $0.result == .blocked }.count

        let uniqueClients = Set(allEntries.map(\.clientId)).count

        return AuditStatistics(
            totalEntries: allEntries.count,
            entriesLast24Hours: last24h.count,
            entriesLastWeek: lastWeek.count,
            failedAuthentications: failedAuth,
            blockedActions: blockedActions,
            uniqueClients: uniqueClients,
            oldestEntry: allEntries.last?.timestamp,
            newestEntry: allEntries.first?.timestamp
        )
    }

    // MARK: - Private

    private func loadEntries() {
        guard FileManager.default.fileExists(atPath: entriesFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: entriesFileURL)
            allEntries = try JSONDecoder().decode([AuditEntry].self, from: data)
            recentEntries = Array(allEntries.prefix(maxInMemoryEntries))
            totalEntryCount = allEntries.count
        } catch {
            logger.error("Failed to load audit entries: \(error.localizedDescription)")
        }
    }

    private func saveEntries() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(allEntries)
            try data.write(to: entriesFileURL)
        } catch {
            logger.error("Failed to save audit entries: \(error.localizedDescription)")
        }
    }

    private func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"" + string.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return string
    }
}

// MARK: - Audit Entry

public struct AuditEntry: Codable, Identifiable, Sendable {
    public let id: String
    public let timestamp: Date
    public let action: AuditAction
    public let sessionId: String
    public let clientId: String
    public let clientName: String
    public let details: String
    public let result: AuditResult

    public init(
        action: AuditAction,
        sessionId: String,
        clientId: String,
        clientName: String,
        details: String,
        result: AuditResult
    ) {
        id = UUID().uuidString
        timestamp = Date()
        self.action = action
        self.sessionId = sessionId
        self.clientId = clientId
        self.clientName = clientName
        self.details = details
        self.result = result
    }
}

// MARK: - Audit Action

public enum AuditAction: String, Codable, Sendable, CaseIterable {
    // Session
    case sessionStarted
    case sessionEnded
    case connectionRejected

    // Authentication
    case authenticationSucceeded
    case authenticationFailed
    case totpVerified
    case totpFailed

    // Screen
    case screenViewed
    case screenControlled
    case screenRecordingStarted
    case screenRecordingStopped

    // Files
    case fileRead
    case fileWritten
    case fileDeleted
    case fileMoved
    case fileCopied
    case directoryListed

    // System
    case commandExecuted
    case processKilled
    case systemReboot
    case systemShutdown
    case systemSleep
    case systemLock

    // Clipboard
    case clipboardSynced

    // Permissions
    case permissionDenied
    case permissionGranted

    // Security
    case rateLimitExceeded
    case suspiciousActivity
    case fileAccessBlocked
    case commandBlocked
    case privacyModeEnabled
    case privacyModeDisabled

    // Server
    case serverStarted
    case serverStopped
    case serverError
    case configurationChanged

    public var displayName: String {
        switch self {
        case .sessionStarted: "Session Started"
        case .sessionEnded: "Session Ended"
        case .connectionRejected: "Connection Rejected"
        case .authenticationSucceeded: "Auth Succeeded"
        case .authenticationFailed: "Auth Failed"
        case .totpVerified: "TOTP Verified"
        case .totpFailed: "TOTP Failed"
        case .screenViewed: "Screen Viewed"
        case .screenControlled: "Screen Controlled"
        case .screenRecordingStarted: "Recording Started"
        case .screenRecordingStopped: "Recording Stopped"
        case .fileRead: "File Read"
        case .fileWritten: "File Written"
        case .fileDeleted: "File Deleted"
        case .fileMoved: "File Moved"
        case .fileCopied: "File Copied"
        case .directoryListed: "Directory Listed"
        case .commandExecuted: "Command Executed"
        case .processKilled: "Process Killed"
        case .systemReboot: "System Reboot"
        case .systemShutdown: "System Shutdown"
        case .systemSleep: "System Sleep"
        case .systemLock: "System Lock"
        case .clipboardSynced: "Clipboard Synced"
        case .permissionDenied: "Permission Denied"
        case .permissionGranted: "Permission Granted"
        case .rateLimitExceeded: "Rate Limit Exceeded"
        case .suspiciousActivity: "Suspicious Activity"
        case .fileAccessBlocked: "File Access Blocked"
        case .commandBlocked: "Command Blocked"
        case .privacyModeEnabled: "Privacy Mode On"
        case .privacyModeDisabled: "Privacy Mode Off"
        case .serverStarted: "Server Started"
        case .serverStopped: "Server Stopped"
        case .serverError: "Server Error"
        case .configurationChanged: "Config Changed"
        }
    }

    public var severity: RemoteAuditSeverity {
        switch self {
        case .authenticationFailed, .connectionRejected, .permissionDenied,
             .rateLimitExceeded, .suspiciousActivity, .fileAccessBlocked,
             .commandBlocked, .totpFailed:
            .warning
        case .systemReboot, .systemShutdown, .fileDeleted, .processKilled,
             .serverError:
            .critical
        case .screenControlled, .fileWritten, .commandExecuted,
             .configurationChanged, .privacyModeEnabled, .privacyModeDisabled:
            .elevated
        default:
            .info
        }
    }
}

// MARK: - Audit Result

public enum AuditResult: String, Codable, Sendable {
    case success
    case failure
    case denied
    case blocked
    case timeout
}

// MARK: - Remote Audit Severity

public enum RemoteAuditSeverity: Int, Codable, Sendable, Comparable {
    case info = 0
    case elevated = 1
    case warning = 2
    case critical = 3

    public static func < (lhs: RemoteAuditSeverity, rhs: RemoteAuditSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayName: String {
        switch self {
        case .info: "Info"
        case .elevated: "Elevated"
        case .warning: "Warning"
        case .critical: "Critical"
        }
    }
}

// MARK: - Export Format

public enum ExportFormat: String, Sendable {
    case csv
    case json
}

// MARK: - Audit Statistics

public struct AuditStatistics: Sendable {
    public let totalEntries: Int
    public let entriesLast24Hours: Int
    public let entriesLastWeek: Int
    public let failedAuthentications: Int
    public let blockedActions: Int
    public let uniqueClients: Int
    public let oldestEntry: Date?
    public let newestEntry: Date?
}
