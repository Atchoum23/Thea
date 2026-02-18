// AgentSecAuditLog.swift
// Audit logging for AgentSec Strict Mode
// Records all security-relevant operations

import Foundation
import OSLog

// MARK: - AgentSec Audit Log

/// Audit logger for security-relevant events
/// Provides tamper-evident logging of all AgentSec operations
@MainActor
public final class AgentSecAuditLog: ObservableObject {
    public static let shared = AgentSecAuditLog()

    private let logger = Logger(subsystem: "com.thea.app", category: "AgentSecAuditLog")

    // MARK: - Configuration

    private let maxEntriesInMemory = 1000
    private let logFilePath: URL

    // MARK: - Published State

    @Published public private(set) var entries: [AgentSecAuditEntry] = []
    @Published public private(set) var totalEntryCount: Int = 0

    // MARK: - Initialization

    private init() {
        // Set up log file path
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            // Fallback to temporary directory
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("Thea")
            do {
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            } catch {
                logger.debug("Could not create temp audit log directory: \(error.localizedDescription)")
            }
            logFilePath = tempDir.appendingPathComponent("agentsec-audit.log")
            loadRecentEntries()
            return
        }
        let theaDir = appSupport.appendingPathComponent("Thea", isDirectory: true)

        // Create directory if needed
        do {
            try FileManager.default.createDirectory(at: theaDir, withIntermediateDirectories: true)
        } catch {
            logger.debug("Could not create audit log directory: \(error.localizedDescription)")
        }

        logFilePath = theaDir.appendingPathComponent("agentsec-audit.log")

        // Load recent entries from file
        loadRecentEntries()
    }

    // MARK: - Logging Methods

    /// Log a security event
    public func log(
        event: AuditEventType,
        details: String,
        severity: AuditSeverity = .info,
        context: [String: String] = [:]
    ) {
        let entry = AgentSecAuditEntry(
            event: event,
            details: details,
            severity: severity,
            context: context
        )

        // Add to in-memory list
        entries.append(entry)
        totalEntryCount += 1

        // Trim if needed
        if entries.count > maxEntriesInMemory {
            entries.removeFirst(entries.count - maxEntriesInMemory)
        }

        // Write to file
        writeEntryToFile(entry)

        // Log to system logger
        switch severity {
        case .critical:
            logger.critical("[\(event.rawValue)] \(details)")
        case .high:
            logger.error("[\(event.rawValue)] \(details)")
        case .medium:
            logger.warning("[\(event.rawValue)] \(details)")
        case .low, .info:
            logger.info("[\(event.rawValue)] \(details)")
        }
    }

    /// Log a network request
    public func logNetworkRequest(url: String, method: String, allowed: Bool) {
        log(
            event: allowed ? .networkRequestAllowed : .networkRequestBlocked,
            details: "\(method) \(url)",
            severity: allowed ? .info : .high,
            context: ["url": url, "method": method, "allowed": String(allowed)]
        )
    }

    /// Log a file operation
    public func logFileOperation(path: String, operation: String, allowed: Bool) {
        log(
            event: allowed ? .fileOperationAllowed : .fileOperationBlocked,
            details: "\(operation) \(path)",
            severity: allowed ? .info : .high,
            context: ["path": path, "operation": operation, "allowed": String(allowed)]
        )
    }

    /// Log a terminal command
    public func logTerminalCommand(command: String, allowed: Bool, requiresApproval: Bool = false) {
        let event: AuditEventType = if !allowed {
            .terminalCommandBlocked
        } else if requiresApproval {
            .terminalCommandApprovalRequired
        } else {
            .terminalCommandAllowed
        }

        log(
            event: event,
            details: command,
            severity: allowed ? .info : .high,
            context: ["command": command, "allowed": String(allowed)]
        )
    }

    /// Log an approval decision
    public func logApproval(operation: String, approved: Bool, reason: String? = nil) {
        log(
            event: approved ? .approvalGranted : .approvalDenied,
            details: "\(operation): \(reason ?? (approved ? "approved" : "denied"))",
            severity: approved ? .info : .medium,
            context: ["operation": operation, "approved": String(approved)]
        )
    }

    // MARK: - Query Methods

    /// Get entries by event type
    public func entries(for eventType: AuditEventType) -> [AgentSecAuditEntry] {
        entries.filter { $0.event == eventType }
    }

    /// Get entries by severity
    public func entries(withSeverity severity: AuditSeverity) -> [AgentSecAuditEntry] {
        entries.filter { $0.severity == severity }
    }

    /// Get entries in time range
    public func entries(from startDate: Date, to endDate: Date) -> [AgentSecAuditEntry] {
        entries.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }

    /// Get recent entries (last N)
    public func recentEntries(_ count: Int = 100) -> [AgentSecAuditEntry] {
        Array(entries.suffix(count))
    }

    // MARK: - File Operations

    private func writeEntryToFile(_ entry: AgentSecAuditEntry) {
        let formatter = ISO8601DateFormatter()
        let line = "\(formatter.string(from: entry.timestamp))|\(entry.severity.rawValue)|\(entry.event.rawValue)|\(entry.details)|\(entry.contextString)\n"

        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: logFilePath.path) {
            do {
                let fileHandle = try FileHandle(forWritingTo: logFilePath)
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                do {
                    try fileHandle.close()
                } catch {
                    logger.debug("Could not close audit log file handle: \(error.localizedDescription)")
                }
            } catch {
                logger.debug("Could not open audit log for appending: \(error.localizedDescription)")
            }
        } else {
            do {
                try data.write(to: logFilePath)
            } catch {
                logger.debug("Could not create audit log file: \(error.localizedDescription)")
            }
        }
    }

    private func loadRecentEntries() {
        guard FileManager.default.fileExists(atPath: logFilePath.path) else { return }

        do {
            let content = try String(contentsOf: logFilePath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            // Parse last N lines
            let recentLines = lines.suffix(maxEntriesInMemory)
            let formatter = ISO8601DateFormatter()

            for line in recentLines where !line.isEmpty {
                let parts = line.components(separatedBy: "|")
                guard parts.count >= 4 else { continue }

                if let timestamp = formatter.date(from: parts[0]),
                   let severity = AuditSeverity(rawValue: parts[1]),
                   let event = AuditEventType(rawValue: parts[2])
                {
                    let entry = AgentSecAuditEntry(
                        id: UUID(),
                        timestamp: timestamp,
                        event: event,
                        details: parts[3],
                        severity: severity,
                        context: [:]
                    )
                    entries.append(entry)
                }
            }

            totalEntryCount = lines.count
        } catch {
            logger.error("Failed to load audit log: \(error.localizedDescription)")
        }
    }

    /// Export audit log to file
    public func export(to path: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(entries)
        try data.write(to: path)
    }

    /// Clear in-memory entries (file log preserved)
    public func clearMemory() {
        entries.removeAll()
    }
}

// MARK: - Audit Entry

/// A single audit log entry
public struct AgentSecAuditEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let event: AuditEventType
    public let details: String
    public let severity: AuditSeverity
    public let context: [String: String]

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        event: AuditEventType,
        details: String,
        severity: AuditSeverity,
        context: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.details = details
        self.severity = severity
        self.context = context
    }

    var contextString: String {
        context.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
    }
}

// MARK: - Audit Event Type

public enum AuditEventType: String, Codable, CaseIterable, Sendable {
    // Policy events
    case policyLoaded = "policy_loaded"
    case policyUpdated = "policy_updated"
    case strictModeEnabled = "strict_mode_enabled"
    case strictModeDisabled = "strict_mode_disabled"

    // Network events
    case networkRequestAllowed = "network_allowed"
    case networkRequestBlocked = "network_blocked"

    // File events
    case fileOperationAllowed = "file_allowed"
    case fileOperationBlocked = "file_blocked"

    // Terminal events
    case terminalCommandAllowed = "terminal_allowed"
    case terminalCommandBlocked = "terminal_blocked"
    case terminalCommandApprovalRequired = "terminal_approval_required"

    // Approval events
    case approvalRequested = "approval_requested"
    case approvalGranted = "approval_granted"
    case approvalDenied = "approval_denied"
    case approvalTimeout = "approval_timeout"

    // Kill switch events
    case killSwitchTriggered = "kill_switch_triggered"
    case killSwitchReset = "kill_switch_reset"

    // Violation events
    case securityViolation = "security_violation"
}

// MARK: - Audit Severity

public enum AuditSeverity: String, Codable, CaseIterable, Sendable, Comparable {
    case critical
    case high
    case medium
    case low
    case info

    var numericValue: Int {
        switch self {
        case .critical: 5
        case .high: 4
        case .medium: 3
        case .low: 2
        case .info: 1
        }
    }

    public static func < (lhs: AuditSeverity, rhs: AuditSeverity) -> Bool {
        lhs.numericValue < rhs.numericValue
    }
}
