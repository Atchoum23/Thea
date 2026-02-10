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

// MARK: - Knowledge Source Manager

/// Central manager for knowledge sources and autonomous monitoring
@MainActor
public final class KnowledgeSourceManager: ObservableObject {
    public static let shared = KnowledgeSourceManager()

    private let logger = Logger(subsystem: "com.thea.v2", category: "KnowledgeSourceManager")
    private let storageKey = "knowledge_sources"

    @Published public private(set) var sources: [KnowledgeSource] = []
    @Published public private(set) var isAuditing: Bool = false
    @Published public private(set) var auditProgress: Double = 0

    private var auditTimer: Timer?

    private var storagePath: URL {
        #if os(macOS)
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".thea/knowledge_sources.json")
        #else
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Thea/knowledge_sources.json")
        #endif
    }

    private init() {
        Task {
            await load()
            scheduleAutomaticAudits()
        }
    }

    // MARK: - CRUD Operations

    /// Add a new knowledge source
    public func add(_ source: KnowledgeSource) {
        sources.append(source)
        save()
        logger.info("Added knowledge source: \(source.name)")
    }

    /// Update an existing knowledge source
    public func update(_ source: KnowledgeSource) {
        if let index = sources.firstIndex(where: { $0.id == source.id }) {
            sources[index] = source
            save()
            logger.info("Updated knowledge source: \(source.name)")
        }
    }

    /// Delete a knowledge source
    public func delete(_ source: KnowledgeSource) {
        sources.removeAll { $0.id == source.id }
        save()
        logger.info("Deleted knowledge source: \(source.name)")
    }

    /// Delete multiple knowledge sources
    public func delete(at offsets: IndexSet) {
        sources.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Audit Operations

    /// Audit a single knowledge source
    public func audit(_ source: KnowledgeSource) async {
        guard var updatedSource = sources.first(where: { $0.id == source.id }) else { return }

        updatedSource.status = .auditing
        update(updatedSource)

        logger.info("Starting audit of: \(source.name)")

        do {
            // 1. Fetch the main page content
            let (content, contentHash) = try await fetchPageContent(source.url)

            // 2. Check if content has changed
            let hasChanged = contentHash != updatedSource.contentHash

            if hasChanged || updatedSource.extractedFeatures.isEmpty {
                // 3. Extract features from the content
                let extractedFeatures = await extractFeatures(from: content, source: source)

                // 4. Convert extracted features to knowledge items
                await convertFeaturesToKnowledge(features: extractedFeatures, source: source)

                // 5. Update source with new data
                updatedSource.extractedFeatures = extractedFeatures
                updatedSource.contentHash = contentHash
                updatedSource.changeDetectedAt = hasChanged ? Date() : updatedSource.changeDetectedAt

                logger.info("Extracted \(extractedFeatures.count) features from \(source.name)")
            } else {
                logger.info("No changes detected for \(source.name)")
            }

            updatedSource.status = .upToDate
            updatedSource.lastAuditedAt = Date()
            updatedSource.errorMessage = nil

        } catch {
            logger.error("Audit failed for \(source.name): \(error.localizedDescription)")
            updatedSource.status = .error
            updatedSource.errorMessage = error.localizedDescription
        }

        update(updatedSource)
        logger.info("Completed audit of: \(source.name)")
    }

    /// Fetch page content and compute hash
    private func fetchPageContent(_ url: URL) async throws -> (String, String) {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuditError.fetchFailed("HTTP error")
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw AuditError.fetchFailed("Invalid encoding")
        }

        // Compute content hash for change detection
        let hash = computeHash(content)

        return (content, hash)
    }

    /// Compute a simple hash of content for change detection
    private func computeHash(_ content: String) -> String {
        var hasher = Hasher()
        hasher.combine(content)
        return String(hasher.finalize())
    }

    /// Extract features from page content
    private func extractFeatures(from content: String, source: KnowledgeSource) async -> [ExtractedFeature] {
        var features: [ExtractedFeature] = []

        // Extract based on category
        switch source.category {
        case .aiProvider:
            features.append(contentsOf: extractAIProviderFeatures(content))
        case .documentation, .framework, .tool, .bestPractices:
            features.append(contentsOf: extractDocumentationFeatures(content))
        case .tutorial:
            features.append(contentsOf: extractTutorialFeatures(content))
        case .reference, .apiReference:
            features.append(contentsOf: extractReferenceFeatures(content))
        case .other:
            features.append(contentsOf: extractGenericFeatures(content))
        }

        return features
    }

    /// Extract AI provider specific features (APIs, models, patterns)
    private func extractAIProviderFeatures(_ content: String) -> [ExtractedFeature] {
        var features: [ExtractedFeature] = []

        // Look for API patterns
        if content.contains("api") || content.contains("API") {
            features.append(ExtractedFeature(
                name: "API Integration",
                description: "API endpoints and integration patterns",
                implementationStatus: .notStarted,
                extractedAt: Date()
            ))
        }

        // Look for model information
        if content.contains("model") || content.contains("Model") {
            features.append(ExtractedFeature(
                name: "Model Configuration",
                description: "Model types and configuration options",
                implementationStatus: .notStarted,
                extractedAt: Date()
            ))
        }

        // Look for streaming patterns
        if content.contains("stream") || content.contains("Stream") {
            features.append(ExtractedFeature(
                name: "Streaming Support",
                description: "Real-time streaming capabilities",
                implementationStatus: .notStarted,
                extractedAt: Date()
            ))
        }

        return features
    }

    /// Extract documentation features
    private func extractDocumentationFeatures(_ content: String) -> [ExtractedFeature] {
        var features: [ExtractedFeature] = []

        if content.contains("getting started") || content.contains("quickstart") {
            features.append(ExtractedFeature(
                name: "Getting Started Guide",
                description: "Quickstart documentation",
                implementationStatus: .notStarted,
                extractedAt: Date()
            ))
        }

        return features
    }

    /// Extract tutorial features
    private func extractTutorialFeatures(_ _content: String) -> [ExtractedFeature] {
        // Tutorials often contain step-by-step instructions
        [ExtractedFeature(
            name: "Tutorial Content",
            description: "Step-by-step learning material",
            implementationStatus: .notStarted,
            extractedAt: Date()
        )]
    }

    /// Extract reference features
    private func extractReferenceFeatures(_ _content: String) -> [ExtractedFeature] {
        [ExtractedFeature(
            name: "Reference Material",
            description: "Technical reference documentation",
            implementationStatus: .notStarted,
            extractedAt: Date()
        )]
    }

    /// Extract generic features
    private func extractGenericFeatures(_ _content: String) -> [ExtractedFeature] {
        [ExtractedFeature(
            name: "General Content",
            description: "General information and patterns",
            implementationStatus: .notStarted,
            extractedAt: Date()
        )]
    }

    /// Convert extracted features to project knowledge items
    private func convertFeaturesToKnowledge(features: [ExtractedFeature], source: KnowledgeSource) async {
        let knowledgeManager = ProjectKnowledgeManager.shared

        for feature in features where feature.implementationStatus != .implemented {
            let knowledgeItem = ProjectKnowledgeItem(
                id: UUID(),
                title: "\(source.name): \(feature.name)",
                content: feature.description,
                scope: .global,
                category: mapSourceCategoryToKnowledgeCategory(source.category),
                isEnabled: true,
                createdAt: Date(),
                updatedAt: Date(),
                tags: [source.name.lowercased(), feature.name.lowercased()],
                appliesTo: []
            )

            knowledgeManager.add(knowledgeItem)
            logger.debug("Added knowledge item: \(knowledgeItem.title)")
        }
    }

    /// Map source category to knowledge category
    private func mapSourceCategoryToKnowledgeCategory(_ category: KnowledgeSourceCategory) -> ProjectKnowledgeCategory {
        switch category {
        case .aiProvider:
            return .integrations
        case .documentation:
            return .guidelines
        case .tutorial:
            return .coding
        case .reference, .apiReference:
            return .architecture
        case .framework, .tool, .bestPractices, .other:
            return .guidelines
        }
    }

    /// Audit error types
    enum AuditError: Error {
        case fetchFailed(String)
        case parsingFailed(String)
        case invalidContent
    }

    /// Audit all enabled sources
    public func auditAll() async {
        isAuditing = true
        auditProgress = 0

        let enabledSources = sources.filter { $0.isEnabled }
        let total = enabledSources.count

        for (index, source) in enabledSources.enumerated() {
            await audit(source)
            auditProgress = Double(index + 1) / Double(total)
        }

        isAuditing = false
        auditProgress = 1.0
        logger.info("Completed audit of all \(total) sources")
    }

    /// Check for changes in a source (polling)
    public func checkForChanges(_ source: KnowledgeSource) async -> Bool {
        do {
            let (_, newHash) = try await fetchPageContent(source.url)
            let hasChanged = newHash != source.contentHash

            if hasChanged {
                logger.info("Changes detected for \(source.name)")

                // Update change detection timestamp
                if var updatedSource = sources.first(where: { $0.id == source.id }) {
                    updatedSource.changeDetectedAt = Date()
                    updatedSource.status = .needsAudit
                    update(updatedSource)
                }
            }

            return hasChanged
        } catch {
            logger.error("Change detection failed for \(source.name): \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Scheduling

    /// Schedule automatic audits based on frequency settings
    public func scheduleAutomaticAudits() {
        // Cancel existing timer
        auditTimer?.invalidate()

        // Find the shortest interval among enabled sources
        let shortestInterval = sources
            .filter { $0.isEnabled && $0.auditFrequency != .manual && $0.auditFrequency != .realtime }
            .compactMap { $0.auditFrequency.interval }
            .min()

        guard let interval = shortestInterval else {
            logger.debug("No automatic audits scheduled")
            return
        }

        // Schedule timer
        auditTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.runScheduledAudits()
            }
        }

        logger.info("Scheduled automatic audits every \(interval) seconds")
    }

    /// Run audits for sources that are due
    private func runScheduledAudits() async {
        let now = Date()

        for source in sources where source.isEnabled {
            guard let interval = source.auditFrequency.interval else { continue }

            let shouldAudit: Bool
            if let lastAudit = source.lastAuditedAt {
                shouldAudit = now.timeIntervalSince(lastAudit) >= interval
            } else {
                shouldAudit = true  // Never audited
            }

            if shouldAudit {
                await audit(source)
            }
        }
    }

    // MARK: - Persistence

    /// Load sources from storage
    private func load() async {
        guard FileManager.default.fileExists(atPath: storagePath.path) else {
            // Load default sources
            loadDefaultSources()
            return
        }

        do {
            let data = try Data(contentsOf: storagePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            sources = try decoder.decode([KnowledgeSource].self, from: data)
            logger.info("Loaded \(self.sources.count) knowledge sources")
        } catch {
            logger.error("Failed to load knowledge sources: \(error.localizedDescription)")
            loadDefaultSources()
        }
    }

    /// Save sources to storage
    private func save() {
        do {
            // Ensure directory exists
            let directory = storagePath.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(sources)
            try data.write(to: storagePath)
            logger.debug("Saved \(self.sources.count) knowledge sources")
        } catch {
            logger.error("Failed to save knowledge sources: \(error.localizedDescription)")
        }
    }

    /// Load default knowledge sources
    private func loadDefaultSources() {
        sources = [
            KnowledgeSource(
                url: URL(string: "https://platform.claude.com/docs")!,
                name: "Claude API",
                description: "Anthropic Claude API documentation",
                category: .aiProvider,
                auditFrequency: .weekly
            ),
            KnowledgeSource(
                url: URL(string: "https://modelcontextprotocol.io/docs")!,
                name: "MCP Protocol",
                description: "Model Context Protocol specification",
                category: .documentation,
                auditFrequency: .weekly
            ),
            KnowledgeSource(
                url: URL(string: "https://platform.openai.com/docs")!,
                name: "OpenAI API",
                description: "OpenAI API documentation",
                category: .aiProvider,
                auditFrequency: .weekly
            ),
            KnowledgeSource(
                url: URL(string: "https://ai.google.dev/gemini-api/docs")!,
                name: "Gemini API",
                description: "Google Gemini API documentation",
                category: .aiProvider,
                auditFrequency: .weekly
            ),
            KnowledgeSource(
                url: URL(string: "https://docs.x.ai/docs")!,
                name: "xAI/Grok API",
                description: "xAI Grok API documentation",
                category: .aiProvider,
                auditFrequency: .weekly
            ),
            KnowledgeSource(
                url: URL(string: "https://api-docs.deepseek.com")!,
                name: "DeepSeek API",
                description: "DeepSeek API documentation",
                category: .aiProvider,
                auditFrequency: .weekly
            ),
            KnowledgeSource(
                url: URL(string: "https://docs.perplexity.ai")!,
                name: "Perplexity API",
                description: "Perplexity API documentation",
                category: .aiProvider,
                auditFrequency: .weekly
            ),
            KnowledgeSource(
                url: URL(string: "https://docs.vapi.ai")!,
                name: "Vapi",
                description: "Voice AI with squads and handoffs",
                category: .tool,
                auditFrequency: .weekly
            ),
            KnowledgeSource(
                url: URL(string: "https://docs.lovable.dev")!,
                name: "Lovable",
                description: "AI coding assistant patterns",
                category: .tool,
                auditFrequency: .weekly
            ),
            KnowledgeSource(
                url: URL(string: "https://support.bolt.new")!,
                name: "Bolt",
                description: "AI development assistant",
                category: .tool,
                auditFrequency: .weekly
            ),
            KnowledgeSource(
                url: URL(string: "https://cursor.com/en-US/docs")!,
                name: "Cursor",
                description: "AI code editor documentation",
                category: .tool,
                auditFrequency: .weekly
            ),
            KnowledgeSource(
                url: URL(string: "https://huggingface.co/docs")!,
                name: "HuggingFace",
                description: "ML platform and smolagents",
                category: .framework,
                auditFrequency: .weekly
            )
        ]
        save()
        logger.info("Loaded \(self.sources.count) default knowledge sources")
    }

    // MARK: - Statistics

    /// Get statistics about knowledge sources
    public var statistics: KnowledgeSourceStatistics {
        KnowledgeSourceStatistics(
            totalSources: sources.count,
            enabledSources: sources.filter { $0.isEnabled }.count,
            sourcesWithChanges: sources.filter { $0.status == .changesDetected }.count,
            totalFeatures: sources.flatMap { $0.extractedFeatures }.count,
            implementedFeatures: sources.flatMap { $0.extractedFeatures }.filter { $0.isImplemented }.count,
            lastAuditDate: sources.compactMap { $0.lastAuditedAt }.max()
        )
    }
}

// MARK: - Knowledge Source Statistics

/// Statistics for knowledge source tracking (prefixed to avoid conflict with HDKnowledgeScanner)
public struct KnowledgeSourceStatistics: Sendable {
    public let totalSources: Int
    public let enabledSources: Int
    public let sourcesWithChanges: Int
    public let totalFeatures: Int
    public let implementedFeatures: Int
    public let lastAuditDate: Date?

    public var implementationPercentage: Double {
        guard totalFeatures > 0 else { return 0 }
        return Double(implementedFeatures) / Double(totalFeatures) * 100
    }
}
