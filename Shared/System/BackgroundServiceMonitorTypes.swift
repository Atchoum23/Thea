// BackgroundServiceMonitorTypes.swift
// Thea V4 — Data types for background service monitoring
//
// Extracted from BackgroundServiceMonitor.swift (SRP: data types are
// separate from the monitoring/recovery logic).

import Foundation

// MARK: - Service Status

/// Status of a monitored service
enum TheaServiceStatus: String, Codable, Sendable, CaseIterable {
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

// MARK: - Service Category

/// Category of monitored service
enum TheaServiceCategory: String, Codable, Sendable, CaseIterable {
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

// MARK: - Health Check Result

/// A single health check result for a service
struct TheaServiceCheckResult: Codable, Sendable, Identifiable {
    let id: UUID
    let serviceID: String
    let serviceName: String
    let category: TheaServiceCategory
    let status: TheaServiceStatus
    let message: String
    let latencyMs: Double?
    let timestamp: Date
    let recoveryAttempted: Bool
    let recoverySucceeded: Bool?

    init(
        serviceID: String,
        serviceName: String,
        category: TheaServiceCategory,
        status: TheaServiceStatus,
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

// MARK: - Health Snapshot

/// Aggregate health snapshot of all services
struct TheaHealthSnapshot: Codable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let checks: [TheaServiceCheckResult]
    let overallStatus: TheaServiceStatus
    let healthyCount: Int
    let degradedCount: Int
    let unhealthyCount: Int
    let recoveryCount: Int

    init(checks: [TheaServiceCheckResult]) {
        self.id = UUID()
        self.timestamp = Date()
        self.checks = checks
        self.healthyCount = checks.filter { $0.status == .healthy }.count
        self.degradedCount = checks.filter { $0.status == .degraded }.count
        self.unhealthyCount = checks.filter { $0.status == .unhealthy }.count
        self.recoveryCount = checks.filter { $0.status == .recovering }.count

        if unhealthyCount > 0 {
            self.overallStatus = .unhealthy
        } else if degradedCount > 0 || recoveryCount > 0 {
            self.overallStatus = .degraded
        } else if healthyCount > 0 {
            self.overallStatus = .healthy
        } else {
            self.overallStatus = .unknown
        }
    }
}

// MARK: - Recovery Action

/// Recovery action that can be performed
struct TheaRecoveryAction: Codable, Sendable, Identifiable {
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

// MARK: - Persistence Model

struct SaveableHealthHistory: Codable {
    let snapshots: [TheaHealthSnapshot]
    let recoveries: [TheaRecoveryAction]
    let consecutiveFailures: [String: Int]
}
