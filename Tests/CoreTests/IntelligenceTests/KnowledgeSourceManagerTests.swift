@testable import TheaCore
import XCTest

@MainActor
final class KnowledgeSourceManagerTests: XCTestCase {

    // MARK: - Manager Instance Tests

    func testManagerSharedInstance() {
        let manager = KnowledgeSourceManager.shared
        XCTAssertNotNil(manager)
        XCTAssertTrue(manager === KnowledgeSourceManager.shared) // Same instance
    }

    // MARK: - Knowledge Source Creation Tests

    func testKnowledgeSourceCreation() {
        let source = KnowledgeSource(
            url: URL(string: "https://example.com/docs")!,
            name: "Example Docs",
            description: "Documentation for testing",
            category: .documentation,
            auditFrequency: .weekly
        )

        XCTAssertEqual(source.name, "Example Docs")
        XCTAssertEqual(source.description, "Documentation for testing")
        XCTAssertEqual(source.category, .documentation)
        XCTAssertEqual(source.auditFrequency, .weekly)
        XCTAssertTrue(source.isEnabled)
        XCTAssertEqual(source.status, .pending)
    }

    func testKnowledgeSourceCategories() {
        XCTAssertEqual(KnowledgeSourceCategory.aiProvider.rawValue, "AI Provider")
        XCTAssertEqual(KnowledgeSourceCategory.documentation.rawValue, "Documentation")
        XCTAssertEqual(KnowledgeSourceCategory.framework.rawValue, "Framework")
        XCTAssertEqual(KnowledgeSourceCategory.tool.rawValue, "Tool")
        XCTAssertEqual(KnowledgeSourceCategory.tutorial.rawValue, "Tutorial")
        XCTAssertEqual(KnowledgeSourceCategory.apiReference.rawValue, "API Reference")
        XCTAssertEqual(KnowledgeSourceCategory.bestPractices.rawValue, "Best Practices")
    }

    // MARK: - Audit Frequency Tests

    func testAuditFrequencyIntervals() {
        XCTAssertNil(AuditFrequency.realtime.interval) // Webhook-based
        XCTAssertEqual(AuditFrequency.hourly.interval, 3600)
        XCTAssertEqual(AuditFrequency.daily.interval, 86400)
        XCTAssertEqual(AuditFrequency.weekly.interval, 604800)
        XCTAssertEqual(AuditFrequency.monthly.interval, 2592000)
        XCTAssertNil(AuditFrequency.manual.interval)
    }

    // MARK: - Knowledge Source Status Tests

    func testKnowledgeSourceStatuses() {
        XCTAssertEqual(KnowledgeSourceStatus.pending.rawValue, "Pending")
        XCTAssertEqual(KnowledgeSourceStatus.auditing.rawValue, "Auditing")
        XCTAssertEqual(KnowledgeSourceStatus.upToDate.rawValue, "Up to Date")
        XCTAssertEqual(KnowledgeSourceStatus.changesDetected.rawValue, "Changes")
        XCTAssertEqual(KnowledgeSourceStatus.error.rawValue, "Error")
    }

    func testKnowledgeSourceStatusIcons() {
        XCTAssertEqual(KnowledgeSourceStatus.pending.icon, "clock")
        XCTAssertEqual(KnowledgeSourceStatus.auditing.icon, "arrow.triangle.2.circlepath")
        XCTAssertEqual(KnowledgeSourceStatus.upToDate.icon, "checkmark.circle.fill")
        XCTAssertEqual(KnowledgeSourceStatus.changesDetected.icon, "exclamationmark.triangle.fill")
        XCTAssertEqual(KnowledgeSourceStatus.error.icon, "xmark.circle.fill")
    }

    func testKnowledgeSourceStatusColors() {
        XCTAssertEqual(KnowledgeSourceStatus.pending.color, "gray")
        XCTAssertEqual(KnowledgeSourceStatus.auditing.color, "blue")
        XCTAssertEqual(KnowledgeSourceStatus.upToDate.color, "green")
        XCTAssertEqual(KnowledgeSourceStatus.changesDetected.color, "orange")
        XCTAssertEqual(KnowledgeSourceStatus.error.color, "red")
    }

    // MARK: - Extracted Feature Tests

    func testExtractedFeatureCreation() {
        let feature = ExtractedFeature(
            name: "Streaming API",
            description: "Real-time streaming support",
            category: .api,
            sourceUrl: URL(string: "https://example.com/docs/streaming")!,
            priority: .high
        )

        XCTAssertEqual(feature.name, "Streaming API")
        XCTAssertEqual(feature.description, "Real-time streaming support")
        XCTAssertEqual(feature.category, .api)
        XCTAssertEqual(feature.priority, .high)
        XCTAssertFalse(feature.isImplemented)
        XCTAssertEqual(feature.implementationStatus, .notStarted)
    }

    func testFeatureCategories() {
        XCTAssertEqual(KnowledgeFeatureCategory.api.rawValue, "API")
        XCTAssertEqual(KnowledgeFeatureCategory.ui.rawValue, "UI/UX")
        XCTAssertEqual(KnowledgeFeatureCategory.agent.rawValue, "Agent Behavior")
        XCTAssertEqual(KnowledgeFeatureCategory.tool.rawValue, "Tool")
        XCTAssertEqual(KnowledgeFeatureCategory.integration.rawValue, "Integration")
        XCTAssertEqual(KnowledgeFeatureCategory.pattern.rawValue, "Pattern")
        XCTAssertEqual(KnowledgeFeatureCategory.workflow.rawValue, "Workflow")
        XCTAssertEqual(KnowledgeFeatureCategory.model.rawValue, "Model Support")
    }

    func testImplementationStatuses() {
        XCTAssertEqual(ImplementationStatus.notStarted.rawValue, "Not Started")
        XCTAssertEqual(ImplementationStatus.planned.rawValue, "Planned")
        XCTAssertEqual(ImplementationStatus.inProgress.rawValue, "In Progress")
        XCTAssertEqual(ImplementationStatus.implemented.rawValue, "Implemented")
        XCTAssertEqual(ImplementationStatus.skipped.rawValue, "Skipped")
    }

    func testKnowledgeFeaturePrioritySortOrder() {
        XCTAssertEqual(KnowledgeFeaturePriority.critical.sortOrder, 4)
        XCTAssertEqual(KnowledgeFeaturePriority.high.sortOrder, 3)
        XCTAssertEqual(KnowledgeFeaturePriority.medium.sortOrder, 2)
        XCTAssertEqual(KnowledgeFeaturePriority.low.sortOrder, 1)
    }

    // MARK: - Statistics Tests

    func testKnowledgeSourceStatisticsCreation() {
        let stats = KnowledgeSourceStatistics(
            totalSources: 10,
            enabledSources: 8,
            sourcesWithChanges: 2,
            totalFeatures: 50,
            implementedFeatures: 25,
            lastAuditDate: Date()
        )

        XCTAssertEqual(stats.totalSources, 10)
        XCTAssertEqual(stats.enabledSources, 8)
        XCTAssertEqual(stats.sourcesWithChanges, 2)
        XCTAssertEqual(stats.totalFeatures, 50)
        XCTAssertEqual(stats.implementedFeatures, 25)
        XCTAssertNotNil(stats.lastAuditDate)
    }

    func testImplementationPercentageCalculation() {
        let stats = KnowledgeSourceStatistics(
            totalSources: 10,
            enabledSources: 8,
            sourcesWithChanges: 2,
            totalFeatures: 100,
            implementedFeatures: 50,
            lastAuditDate: nil
        )

        XCTAssertEqual(stats.implementationPercentage, 50.0)
    }

    func testImplementationPercentageWithNoFeatures() {
        let stats = KnowledgeSourceStatistics(
            totalSources: 10,
            enabledSources: 8,
            sourcesWithChanges: 0,
            totalFeatures: 0,
            implementedFeatures: 0,
            lastAuditDate: nil
        )

        XCTAssertEqual(stats.implementationPercentage, 0.0)
    }

    // MARK: - Manager Operations Tests

    func testDefaultSourcesLoaded() {
        let manager = KnowledgeSourceManager.shared

        // Should have default sources
        XCTAssertFalse(manager.sources.isEmpty)

        // Should include common AI providers
        let hasClaudeAPI = manager.sources.contains { $0.name.contains("Claude") }
        let hasOpenAI = manager.sources.contains { $0.name.contains("OpenAI") }
        XCTAssertTrue(hasClaudeAPI || hasOpenAI)
    }

    func testStatisticsComputation() {
        let manager = KnowledgeSourceManager.shared
        let stats = manager.statistics

        XCTAssertGreaterThanOrEqual(stats.totalSources, 0)
        XCTAssertGreaterThanOrEqual(stats.enabledSources, 0)
        XCTAssertLessThanOrEqual(stats.enabledSources, stats.totalSources)
    }

    // MARK: - Source with Webhook Tests

    func testKnowledgeSourceWithWebhook() {
        let source = KnowledgeSource(
            url: URL(string: "https://example.com/docs")!,
            name: "Example Docs",
            description: "Documentation with webhook",
            category: .documentation,
            auditFrequency: .realtime,
            webhookUrl: URL(string: "https://example.com/webhook")
        )

        XCTAssertEqual(source.auditFrequency, .realtime)
        XCTAssertNotNil(source.webhookUrl)
        XCTAssertNil(source.auditFrequency.interval) // Realtime has no interval
    }

    // MARK: - Category Icon Tests

    func testCategoryIcons() {
        XCTAssertEqual(KnowledgeSourceCategory.aiProvider.icon, "cpu")
        XCTAssertEqual(KnowledgeSourceCategory.documentation.icon, "doc.text")
        XCTAssertEqual(KnowledgeSourceCategory.framework.icon, "square.grid.3x3")
        XCTAssertEqual(KnowledgeSourceCategory.tool.icon, "wrench.and.screwdriver")
        XCTAssertEqual(KnowledgeSourceCategory.tutorial.icon, "graduationcap")
        XCTAssertEqual(KnowledgeSourceCategory.apiReference.icon, "curlybraces")
        XCTAssertEqual(KnowledgeSourceCategory.bestPractices.icon, "checkmark.seal")
        XCTAssertEqual(KnowledgeSourceCategory.other.icon, "questionmark.circle")
    }
}
