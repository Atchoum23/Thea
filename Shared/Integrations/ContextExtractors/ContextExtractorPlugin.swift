//
//  ContextExtractorPlugin.swift
//  Thea
//
//  Plugin protocol for app context extractors, enabling extensible
//  foreground-app context extraction without modifying the dispatcher.
//

#if os(macOS)
import AppKit
import Foundation

// MARK: - Context Extractor Plugin Protocol

/// Defines the contract for a foreground-app context extractor plugin.
///
/// Instead of hardcoding each app's context extraction logic in
/// ForegroundAppMonitor's switch statement, new extractors can conform
/// to this protocol and register themselves with the ContextExtractorRegistry.
///
/// **What this enables:**
/// - Adding support for a new app (e.g., Figma, Slack, Mail) by creating
///   a single file that conforms to this protocol and self-registers
/// - Third-party or user-contributed extractors without modifying core code
/// - Unit testing extractors in isolation with mock accessibility elements
///
/// **Example usage:**
/// ```swift
/// struct FigmaContextExtractor: ContextExtractorPlugin {
///     static let pluginID = "com.figma.Desktop"
///     static let supportedBundleIDs = ["com.figma.Desktop"]
///     static let displayName = "Figma"
///
///     static func extract(
///         includeSelectedText: Bool,
///         includeWindowContent: Bool
///     ) async -> AppContext? {
///         // ... Figma-specific extraction via Accessibility API
///     }
/// }
/// ```
// periphery:ignore - Reserved: ContextExtractorPlugin protocol — reserved for future feature activation
protocol ContextExtractorPlugin: Sendable {

    /// Unique identifier for this extractor (typically the primary bundle ID)
    static var pluginID: String { get }

    /// Bundle identifiers this extractor handles (one extractor can support multiple)
    static var supportedBundleIDs: [String] { get }

    // periphery:ignore - Reserved: ContextExtractorPlugin protocol reserved for future feature activation
    /// Human-readable name shown in settings UI
    static var displayName: String { get }

    /// Extract context from the frontmost window of the associated app.
    ///
    /// - Parameters:
    ///   - includeSelectedText: Whether to extract the current text selection
    ///   - includeWindowContent: Whether to extract visible content (may be expensive)
    /// - Returns: Extracted context, or nil if the app is not frontmost or extraction fails
    static func extract(
        includeSelectedText: Bool,
        includeWindowContent: Bool
    ) async -> AppContext?
}

// MARK: - Generic Extractor Plugin (with app reference)

/// Extended plugin protocol for extractors that need the running application reference.
///
/// Use this for generic/fallback extractors that work with any app, not just
/// specific bundle IDs. The `GenericContextExtractor` uses this variant.
protocol GenericContextExtractorPlugin: Sendable {

    // periphery:ignore - Reserved: pluginID static property — reserved for future feature activation
    static var pluginID: String { get }
    // periphery:ignore - Reserved: displayName static property — reserved for future feature activation
    static var displayName: String { get }

    /// Extract context from an arbitrary running application.
    // periphery:ignore - Reserved: extract(app:includeSelectedText:includeWindowContent:) static method — reserved for future feature activation
    static func extract(
        // periphery:ignore - Reserved: GenericContextExtractorPlugin protocol reserved for future feature activation
        app: NSRunningApplication,
        includeSelectedText: Bool,
        includeWindowContent: Bool
    ) async -> AppContext?
}

// MARK: - Context Extractor Registry

/// Central registry for context extractor plugins.
///
/// ForegroundAppMonitor queries this registry to find the appropriate extractor
/// for a given bundle ID. Extractors self-register at app startup.
///
/// **Thread safety:** All access is MainActor-isolated (same as ForegroundAppMonitor).
@MainActor
// periphery:ignore - Reserved: ContextExtractorRegistry class — reserved for future feature activation
final class ContextExtractorRegistry {
    static let shared = ContextExtractorRegistry()

    /// Registered extractors, keyed by bundle ID for O(1) lookup
    private var extractors: [String: any ContextExtractorPlugin.Type] = [:]

    // periphery:ignore - Reserved: ContextExtractorRegistry type reserved for future feature activation
    /// Fallback extractor for apps without a specific plugin
    private var fallbackExtractor: (any GenericContextExtractorPlugin.Type)?

    private init() {
        registerBuiltInExtractors()
    }

    // MARK: - Registration

    /// Register a context extractor plugin for its supported bundle IDs.
    func register<T: ContextExtractorPlugin>(_ extractorType: T.Type) {
        for bundleID in extractorType.supportedBundleIDs {
            extractors[bundleID] = extractorType
        }
    }

    /// Register a fallback extractor for apps without a specific plugin.
    func registerFallback<T: GenericContextExtractorPlugin>(_ extractorType: T.Type) {
        fallbackExtractor = extractorType
    }

    /// Unregister all extractors for a specific bundle ID.
    func unregister(bundleID: String) {
        extractors.removeValue(forKey: bundleID)
    }

    // MARK: - Query

    /// Find the extractor that handles the given bundle ID.
    func extractor(for bundleID: String) -> (any ContextExtractorPlugin.Type)? {
        extractors[bundleID]
    }

    /// Get the fallback extractor (for unknown apps).
    func genericExtractor() -> (any GenericContextExtractorPlugin.Type)? {
        fallbackExtractor
    }

    /// All registered bundle IDs.
    var registeredBundleIDs: Set<String> {
        Set(extractors.keys)
    }

    /// All registered extractor display names, keyed by plugin ID.
    var registeredExtractors: [(pluginID: String, displayName: String, bundleIDs: [String])] {
        var seen = Set<String>()
        var result: [(pluginID: String, displayName: String, bundleIDs: [String])] = []
        for (_, extractorType) in extractors {
            guard !seen.contains(extractorType.pluginID) else { continue }
            seen.insert(extractorType.pluginID)
            result.append((
                pluginID: extractorType.pluginID,
                displayName: extractorType.displayName,
                bundleIDs: extractorType.supportedBundleIDs
            ))
        }
        return result.sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Built-in Registration

    /// Registers all built-in extractors. Called once during init.
    private func registerBuiltInExtractors() {
        // Wrap existing enum-based extractors as plugin conformances
        register(XcodeExtractorAdapter.self)
        register(VSCodeExtractorAdapter.self)
        register(TerminalExtractorAdapter.self)
        register(TextEditorExtractorAdapter.self)
        register(SafariExtractorAdapter.self)
        registerFallback(GenericExtractorAdapter.self)
    }
}

// MARK: - Built-in Extractor Adapters

/// Adapts the existing XcodeContextExtractor enum to the plugin protocol.
// periphery:ignore - Reserved: XcodeExtractorAdapter enum — reserved for future feature activation
private enum XcodeExtractorAdapter: ContextExtractorPlugin {
    static let pluginID = "com.apple.dt.Xcode"
    static let supportedBundleIDs = ["com.apple.dt.Xcode"]
    static let displayName = "Xcode"

    // periphery:ignore - Reserved: XcodeExtractorAdapter type reserved for future feature activation
    static func extract(includeSelectedText: Bool, includeWindowContent: Bool) async -> AppContext? {
        await XcodeContextExtractor.extract(
            includeSelectedText: includeSelectedText,
            includeWindowContent: includeWindowContent
        )
    }
}

// periphery:ignore - Reserved: VSCodeExtractorAdapter enum — reserved for future feature activation
private enum VSCodeExtractorAdapter: ContextExtractorPlugin {
    static let pluginID = "com.microsoft.VSCode"
    static let supportedBundleIDs = ["com.microsoft.VSCode"]
    static let displayName = "VS Code"

// periphery:ignore - Reserved: VSCodeExtractorAdapter type reserved for future feature activation

    static func extract(includeSelectedText: Bool, includeWindowContent: Bool) async -> AppContext? {
        await VSCodeContextExtractor.extract(
            includeSelectedText: includeSelectedText,
            includeWindowContent: includeWindowContent
        )
    }
}

// periphery:ignore - Reserved: TerminalExtractorAdapter enum — reserved for future feature activation
private enum TerminalExtractorAdapter: ContextExtractorPlugin {
    static let pluginID = "terminal-apps"
    static let supportedBundleIDs = [
        // periphery:ignore - Reserved: TerminalExtractorAdapter type reserved for future feature activation
        "com.googlecode.iterm2",
        "com.apple.Terminal",
        "dev.warp.Warp-Stable"
    ]
    static let displayName = "Terminal"

    static func extract(includeSelectedText: Bool, includeWindowContent: Bool) async -> AppContext? {
        await TerminalContextExtractor.extract(
            includeSelectedText: includeSelectedText,
            includeWindowContent: includeWindowContent
        )
    }
}

// periphery:ignore - Reserved: TextEditorExtractorAdapter enum — reserved for future feature activation
private enum TextEditorExtractorAdapter: ContextExtractorPlugin {
    static let pluginID = "text-editors"
    // periphery:ignore - Reserved: TextEditorExtractorAdapter type reserved for future feature activation
    static let supportedBundleIDs = ["com.apple.Notes", "com.apple.TextEdit"]
    static let displayName = "Text Editor"

    static func extract(includeSelectedText: Bool, includeWindowContent: Bool) async -> AppContext? {
        await TextEditorContextExtractor.extract(
            includeSelectedText: includeSelectedText,
            includeWindowContent: includeWindowContent
        )
    }
}

// periphery:ignore - Reserved: SafariExtractorAdapter enum — reserved for future feature activation
private enum SafariExtractorAdapter: ContextExtractorPlugin {
    // periphery:ignore - Reserved: SafariExtractorAdapter type reserved for future feature activation
    static let pluginID = "com.apple.Safari"
    static let supportedBundleIDs = ["com.apple.Safari"]
    static let displayName = "Safari"

    static func extract(includeSelectedText: Bool, includeWindowContent: Bool) async -> AppContext? {
        await SafariContextExtractor.extract(
            includeSelectedText: includeSelectedText,
            includeWindowContent: includeWindowContent
        )
    }
}

// periphery:ignore - Reserved: GenericExtractorAdapter type reserved for future feature activation
private enum GenericExtractorAdapter: GenericContextExtractorPlugin {
    static let pluginID = "generic-fallback"
    static let displayName = "Generic App"

    static func extract(
        app: NSRunningApplication,
        includeSelectedText: Bool,
        includeWindowContent: Bool
    ) async -> AppContext? {
        await GenericContextExtractor.extract(
            app: app,
            includeSelectedText: includeSelectedText,
            includeWindowContent: includeWindowContent
        )
    }
}
#endif
