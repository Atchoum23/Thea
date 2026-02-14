// KnowledgeSourceManager.swift
// Thea V2
//
// Knowledge source management and autonomous monitoring
// Features:
// - URL management (add, edit, delete)
// - Scheduled audit frequency
// - Change detection via webhooks or polling
// - Automatic knowledge extraction and updates

import Foundation
import OSLog

// MARK: - Knowledge Source

/// A documented website or API that Thea learns from
public struct KnowledgeSource: Identifiable, Codable, Sendable {
    public let id: UUID
    public var url: URL
    public var name: String
    public var description: String
    public var category: KnowledgeSourceCategory
    public var auditFrequency: AuditFrequency
    public var isEnabled: Bool
    public var lastAuditedAt: Date?
    public var lastChangedAt: Date?
    public var sitemapUrls: [URL]
    public var extractedFeatures: [ExtractedFeature]
    public var status: KnowledgeSourceStatus
    public var createdAt: Date
    public var webhookUrl: URL?  // For real-time change notifications
    public var contentHash: String?  // For change detection
    public var changeDetectedAt: Date?  // When changes were last detected
    public var errorMessage: String?  // Last error message if any

    public init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        description: String = "",
        category: KnowledgeSourceCategory = .documentation,
        auditFrequency: AuditFrequency = .weekly,
        isEnabled: Bool = true,
        lastAuditedAt: Date? = nil,
        lastChangedAt: Date? = nil,
        sitemapUrls: [URL] = [],
        extractedFeatures: [ExtractedFeature] = [],
        status: KnowledgeSourceStatus = .pending,
        createdAt: Date = Date(),
        webhookUrl: URL? = nil,
        contentHash: String? = nil,
        changeDetectedAt: Date? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.description = description
        self.category = category
        self.auditFrequency = auditFrequency
        self.isEnabled = isEnabled
        self.lastAuditedAt = lastAuditedAt
        self.lastChangedAt = lastChangedAt
        self.sitemapUrls = sitemapUrls
        self.extractedFeatures = extractedFeatures
        self.status = status
        self.createdAt = createdAt
        self.webhookUrl = webhookUrl
        self.contentHash = contentHash
        self.changeDetectedAt = changeDetectedAt
        self.errorMessage = errorMessage
    }
}

public enum KnowledgeSourceCategory: String, Codable, Sendable, CaseIterable {
    case aiProvider = "AI Provider"
    case documentation = "Documentation"
    case framework = "Framework"
    case tool = "Tool"
    case tutorial = "Tutorial"
    case apiReference = "API Reference"
    case bestPractices = "Best Practices"
    case reference = "Reference"
    case other = "Other"

    public var icon: String {
        switch self {
        case .aiProvider: return "cpu"
        case .documentation: return "doc.text"
        case .framework: return "square.grid.3x3"
        case .tool: return "wrench.and.screwdriver"
        case .tutorial: return "graduationcap"
        case .apiReference: return "curlybraces"
        case .bestPractices: return "checkmark.seal"
        case .reference: return "book"
        case .other: return "questionmark.circle"
        }
    }
}

public enum AuditFrequency: String, Codable, Sendable, CaseIterable {
    case realtime = "Real-time"      // Via webhook
    case hourly = "Hourly"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case manual = "Manual Only"

    public var interval: TimeInterval? {
        switch self {
        case .realtime: return nil  // Webhook-based
        case .hourly: return 3600
        case .daily: return 86400
        case .weekly: return 604800
        case .monthly: return 2592000
        case .manual: return nil
        }
    }
}

public enum KnowledgeSourceStatus: String, Codable, Sendable {
    case pending = "Pending"           // Not yet audited
    case auditing = "Auditing"         // Currently being audited
    case upToDate = "Up to Date"       // Audited, no changes
    case changesDetected = "Changes"   // Changes detected, needs re-audit
    case needsAudit = "Needs Audit"    // Marked for audit due to detected changes
    case error = "Error"               // Failed to audit

    public var icon: String {
        switch self {
        case .pending: return "clock"
        case .auditing: return "arrow.triangle.2.circlepath"
        case .upToDate: return "checkmark.circle.fill"
        case .changesDetected: return "exclamationmark.triangle.fill"
        case .needsAudit: return "arrow.clockwise"
        case .error: return "xmark.circle.fill"
        }
    }

    public var color: String {
        switch self {
        case .pending: return "gray"
        case .auditing: return "blue"
        case .upToDate: return "green"
        case .changesDetected: return "orange"
        case .needsAudit: return "yellow"
        case .error: return "red"
        }
    }
}

// MARK: - Extracted Feature

/// A feature/capability extracted from a knowledge source
public struct ExtractedFeature: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var category: KnowledgeFeatureCategory
    public var sourceUrl: URL?  // Optional - may not always have a direct URL
    public var isImplemented: Bool
    public var implementationStatus: ImplementationStatus
    public var priority: KnowledgeFeaturePriority
    public var extractedAt: Date
    public var implementedAt: Date?
    public var relatedFiles: [String]

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        category: KnowledgeFeatureCategory = .pattern,
        sourceUrl: URL? = nil,
        isImplemented: Bool = false,
        implementationStatus: ImplementationStatus = .notStarted,
        priority: KnowledgeFeaturePriority = .medium,
        extractedAt: Date = Date(),
        implementedAt: Date? = nil,
        relatedFiles: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.sourceUrl = sourceUrl
        self.isImplemented = isImplemented
        self.implementationStatus = implementationStatus
        self.priority = priority
        self.extractedAt = extractedAt
        self.implementedAt = implementedAt
        self.relatedFiles = relatedFiles
    }
}

/// Feature categories for extracted knowledge (prefixed to avoid conflict with SelfEvolutionEngine types)
public enum KnowledgeFeatureCategory: String, Codable, Sendable, CaseIterable {
    case api = "API"
    case ui = "UI/UX"
    case agent = "Agent Behavior"
    case tool = "Tool"
    case integration = "Integration"
    case pattern = "Pattern"
    case workflow = "Workflow"
    case model = "Model Support"
}

public enum ImplementationStatus: String, Codable, Sendable {
    case notStarted = "Not Started"
    case planned = "Planned"
    case inProgress = "In Progress"
    case implemented = "Implemented"
    case skipped = "Skipped"
}

/// Feature priorities for extracted knowledge (prefixed to avoid conflict)
public enum KnowledgeFeaturePriority: String, Codable, Sendable, CaseIterable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    public var sortOrder: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
}

