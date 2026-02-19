//
//  VerificationPlugin.swift
//  Thea
//
//  Plugin protocol for verification strategies, enabling extensible
//  confidence validation without modifying ConfidenceSystem.
//

import Foundation

// MARK: - Verification Plugin Protocol

/// Defines the contract for a verification strategy plugin.
///
/// The ConfidenceSystem currently hardcodes 5 verifiers (multi-model consensus,
/// web search, code execution, static analysis, user feedback). This protocol
/// enables adding new verification strategies (e.g., citation checking, RAG
/// validation, domain-specific fact checking) without modifying ConfidenceSystem.
///
/// **What this enables:**
/// - New verification strategies can be added by creating a single conforming type
/// - Verification strategies can be enabled/disabled via feature flags
/// - Domain-specific verifiers (e.g., medical fact-checking) can be plugged in
/// - Unit testing of individual verifiers in isolation
///
/// **Example:**
/// ```swift
/// final class CitationVerifier: VerificationPlugin {
///     let pluginID = "citation-verifier"
///     let displayName = "Citation Checker"
///     let sourceType: ConfidenceSource.SourceType = .webVerification
///     var isEnabled = true
///     let defaultWeight = 0.15
///
///     func verify(input: VerificationInput) async -> VerificationOutput {
///         // Check if cited URLs are real and support the claims...
///     }
/// }
/// ```
// periphery:ignore - Reserved: VerificationPlugin protocol — reserved for future feature activation
protocol VerificationPlugin: AnyObject, Sendable {

    /// Unique identifier for this verifier
    var pluginID: String { get }

// periphery:ignore - Reserved: VerificationPlugin protocol reserved for future feature activation

    /// Human-readable name shown in settings/diagnostics
    var displayName: String { get }

    /// The confidence source type this verifier contributes to
    var sourceType: ConfidenceSource.SourceType { get }

    /// Whether this verifier is currently enabled
    var isEnabled: Bool { get set }

    /// Default weight in the confidence calculation (0.0 to 1.0)
    var defaultWeight: Double { get }

    /// Whether this verifier should run for the given task type and context.
    /// Return false to skip this verifier for irrelevant inputs.
    func shouldRun(taskType: TaskType, context: ValidationContext) -> Bool

    /// Execute the verification and return a standardized output.
    func verify(input: VerificationInput) async -> VerificationOutput
}

// MARK: - Verification Input

/// Standardized input for all verification plugins.
/// Contains everything a verifier might need — plugins use what they need
/// and ignore the rest.
// periphery:ignore - Reserved: VerificationInput type — reserved for future feature activation
struct VerificationInput: Sendable {
    /// The AI response being verified
    let response: String

// periphery:ignore - Reserved: VerificationInput type reserved for future feature activation

    /// The user's original query
    let query: String

    /// Classified task type
    let taskType: TaskType

    /// Validation context (permissions, language, latency budget)
    let context: ValidationContext

    init(
        response: String,
        query: String,
        taskType: TaskType,
        context: ValidationContext = .default
    ) {
        self.response = response
        self.query = query
        self.taskType = taskType
        self.context = context
    }
}

// MARK: - Verification Output

/// Standardized output from all verification plugins.
/// Maps directly to what ConfidenceSystem aggregates.
// periphery:ignore - Reserved: VerificationOutput type — reserved for future feature activation
struct VerificationOutput: Sendable {
    /// The confidence source with score and details
    // periphery:ignore - Reserved: VerificationOutput type reserved for future feature activation
    let source: ConfidenceSource

    /// Factors contributing to the confidence score
    let factors: [ConfidenceDecomposition.DecompositionFactor]

    /// Any conflicts detected between sources
    let conflicts: [ConfidenceDecomposition.ConflictInfo]

    init(
        source: ConfidenceSource,
        factors: [ConfidenceDecomposition.DecompositionFactor] = [],
        conflicts: [ConfidenceDecomposition.ConflictInfo] = []
    ) {
        self.source = source
        self.factors = factors
        self.conflicts = conflicts
    }

    /// Convenience: create a "skipped" output for when a verifier decides not to run
    static func skipped(
        pluginID: String,
        sourceType: ConfidenceSource.SourceType,
        reason: String
    ) -> VerificationOutput {
        VerificationOutput(
            source: ConfidenceSource(
                type: sourceType,
                name: pluginID,
                confidence: 0.5,
                weight: 0.0,
                details: "Skipped: \(reason)",
                verified: false
            )
        )
    }
}

// MARK: - Verification Plugin Registry

/// Central registry for verification strategy plugins.
///
/// ConfidenceSystem queries this registry to discover and run all
/// registered verifiers in parallel.
@MainActor
final class VerificationPluginRegistry {
    // periphery:ignore - Reserved: VerificationPluginRegistry type reserved for future feature activation
    static let shared = VerificationPluginRegistry()

    /// Registered verification plugins, keyed by plugin ID
    // periphery:ignore - Reserved: plugins property — reserved for future feature activation
    private var plugins: [String: any VerificationPlugin] = [:]

    private init() {}

    // MARK: - Registration

    /// Register a verification plugin.
    // periphery:ignore - Reserved: register(_:) instance method — reserved for future feature activation
    func register(_ plugin: any VerificationPlugin) {
        plugins[plugin.pluginID] = plugin
    }

    /// Unregister a plugin by ID.
    // periphery:ignore - Reserved: unregister(pluginID:) instance method — reserved for future feature activation
    func unregister(pluginID: String) {
        plugins.removeValue(forKey: pluginID)
    }

    // MARK: - Query

    /// All registered plugins.
    // periphery:ignore - Reserved: allPlugins property — reserved for future feature activation
    var allPlugins: [any VerificationPlugin] {
        Array(plugins.values)
    }

    /// Only enabled plugins.
    // periphery:ignore - Reserved: enabledPlugins property — reserved for future feature activation
    var enabledPlugins: [any VerificationPlugin] {
        plugins.values.filter(\.isEnabled)
    }

    /// Plugins that should run for the given task type and context.
    // periphery:ignore - Reserved: applicablePlugins(taskType:context:) instance method — reserved for future feature activation
    func applicablePlugins(
        taskType: TaskType,
        context: ValidationContext
    ) -> [any VerificationPlugin] {
        enabledPlugins.filter { $0.shouldRun(taskType: taskType, context: context) }
    }

    /// Get a specific plugin by ID.
    // periphery:ignore - Reserved: plugin(id:) instance method — reserved for future feature activation
    func plugin(id: String) -> (any VerificationPlugin)? {
        plugins[id]
    }

    /// Summary of all registered plugins for diagnostics.
    // periphery:ignore - Reserved: diagnosticSummary property — reserved for future feature activation
    var diagnosticSummary: [(id: String, name: String, enabled: Bool, weight: Double)] {
        plugins.values.map { plugin in
            (
                id: plugin.pluginID,
                name: plugin.displayName,
                enabled: plugin.isEnabled,
                weight: plugin.defaultWeight
            )
        }.sorted { $0.name < $1.name }
    }
}

// MARK: - Default shouldRun Implementation

// periphery:ignore - Reserved: VerificationPlugin protocol extension reserved for future feature activation
extension VerificationPlugin {
    /// Default: always run if enabled. Override for task-type filtering.
    func shouldRun(taskType: TaskType, context: ValidationContext) -> Bool {
        isEnabled
    }
}
