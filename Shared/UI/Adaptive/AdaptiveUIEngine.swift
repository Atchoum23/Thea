//
//  AdaptiveUIEngine.swift
//  Thea
//
//  Adaptive UI/UX system that learns from user behavior and adjusts
//  the interface dynamically based on context, preferences, and usage patterns.
//
//  Copyright 2026. All rights reserved.
//

import Combine
import Foundation
import os.log
import SwiftUI

// MARK: - Adaptive UI Types

/// User interaction pattern
public struct InteractionPattern: Codable, Sendable {
    public let action: String
    public let frequency: Int
    public let lastUsed: Date
    public let averageDuration: TimeInterval
    public let context: [String: String]

    public init(
        action: String,
        frequency: Int = 1,
        lastUsed: Date = Date(),
        averageDuration: TimeInterval = 0,
        context: [String: String] = [:]
    ) {
        self.action = action
        self.frequency = frequency
        self.lastUsed = lastUsed
        self.averageDuration = averageDuration
        self.context = context
    }
}

/// UI element visibility preference
public struct UIVisibilityPreference: Codable, Sendable {
    public let elementId: String
    public var isVisible: Bool
    public var priority: Int
    public var lastModified: Date

    public init(elementId: String, isVisible: Bool = true, priority: Int = 0, lastModified: Date = Date()) {
        self.elementId = elementId
        self.isVisible = isVisible
        self.priority = priority
        self.lastModified = lastModified
    }
}

/// Layout configuration
public struct AdaptiveLayout: Codable, Sendable {
    public var sidebarWidth: CGFloat
    public var showSidebar: Bool
    public var chatInputPosition: InputPosition
    public var messageDisplayDensity: DisplayDensity
    public var toolbarItems: [String]
    public var quickActions: [String]
    public var theme: AdaptiveTheme

    public enum InputPosition: String, Codable, Sendable {
        case bottom
        case top
        case floating
    }

    public enum DisplayDensity: String, Codable, Sendable {
        case compact
        case comfortable
        case spacious
    }

    public struct AdaptiveTheme: Codable, Sendable {
        public var colorScheme: ColorSchemePreference
        public var accentColor: String
        public var fontSize: FontSizePreference
        public var reduceMotion: Bool
        public var highContrast: Bool

        public enum ColorSchemePreference: String, Codable, Sendable {
            case system
            case light
            case dark
            case auto  // Changes based on time of day
        }

        public enum FontSizePreference: String, Codable, Sendable {
            case small
            case medium
            case large
            case extraLarge
            case dynamic  // Adjusts based on content
        }

        public init(
            colorScheme: ColorSchemePreference = .system,
            accentColor: String = "blue",
            fontSize: FontSizePreference = .medium,
            reduceMotion: Bool = false,
            highContrast: Bool = false
        ) {
            self.colorScheme = colorScheme
            self.accentColor = accentColor
            self.fontSize = fontSize
            self.reduceMotion = reduceMotion
            self.highContrast = highContrast
        }
    }

    public init(
        sidebarWidth: CGFloat = 280,
        showSidebar: Bool = true,
        chatInputPosition: InputPosition = .bottom,
        messageDisplayDensity: DisplayDensity = .comfortable,
        toolbarItems: [String] = ["newChat", "search", "settings"],
        quickActions: [String] = ["copy", "regenerate", "share"],
        theme: AdaptiveTheme = AdaptiveTheme()
    ) {
        self.sidebarWidth = sidebarWidth
        self.showSidebar = showSidebar
        self.chatInputPosition = chatInputPosition
        self.messageDisplayDensity = messageDisplayDensity
        self.toolbarItems = toolbarItems
        self.quickActions = quickActions
        self.theme = theme
    }
}

/// Context for UI adaptation
public struct UIContext: Sendable {
    public let timeOfDay: TimeOfDay
    public let deviceType: DeviceType
    public let screenSize: CGSize
    public let isAccessibilityEnabled: Bool
    public let currentTask: String?
    public let sessionDuration: TimeInterval

    public enum TimeOfDay: String, Sendable {
        case morning    // 5-12
        case afternoon  // 12-17
        case evening    // 17-21
        case night      // 21-5
    }

    public enum DeviceType: String, Sendable {
        case mac
        case iPhone
        case iPad
        case watch
        case tv
        case vision
    }

    public init(
        timeOfDay: TimeOfDay,
        deviceType: DeviceType,
        screenSize: CGSize,
        isAccessibilityEnabled: Bool = false,
        currentTask: String? = nil,
        sessionDuration: TimeInterval = 0
    ) {
        self.timeOfDay = timeOfDay
        self.deviceType = deviceType
        self.screenSize = screenSize
        self.isAccessibilityEnabled = isAccessibilityEnabled
        self.currentTask = currentTask
        self.sessionDuration = sessionDuration
    }
}

// MARK: - Adaptive UI Engine

/// Engine that learns and adapts the UI based on user behavior
@MainActor
public final class AdaptiveUIEngine: ObservableObject {
    public static let shared = AdaptiveUIEngine()

    private let logger = Logger(subsystem: "ai.thea.app", category: "AdaptiveUI")

    // MARK: - Published State

    /// Current adaptive layout
    @Published public private(set) var layout = AdaptiveLayout()

    /// UI element visibility preferences
    @Published public private(set) var visibilityPreferences: [String: UIVisibilityPreference] = [:]

    /// Interaction patterns
    @Published public private(set) var interactionPatterns: [String: InteractionPattern] = [:]

    /// Current UI context
    @Published public private(set) var context: UIContext?

    /// Whether adaptation is enabled
    @Published public var adaptationEnabled: Bool = true

    /// Learning rate for pattern detection
    @Published public var learningRate: Double = 0.1

    // MARK: - Configuration

    /// Minimum interactions before adapting
    public var minimumInteractionsForAdaptation: Int = 5

    /// Time window for pattern detection (in days)
    public var patternDetectionWindow: TimeInterval = 7 * 24 * 60 * 60

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private let defaults = UserDefaults.standard
    private let storageKey = "thea.adaptive_ui.state"

    // MARK: - Initialization

    private init() {
        loadState()
        updateContext()
        startContextMonitoring()

        logger.info("AdaptiveUIEngine initialized")
    }

    // MARK: - Public API

    /// Record a user interaction
    public func recordInteraction(
        action: String,
        duration: TimeInterval = 0,
        context: [String: String] = [:]
    ) {
        guard adaptationEnabled else { return }

        var pattern = interactionPatterns[action] ?? InteractionPattern(action: action)

        let newFrequency = pattern.frequency + 1
        let newAverageDuration = (pattern.averageDuration * Double(pattern.frequency) + duration) / Double(newFrequency)

        pattern = InteractionPattern(
            action: action,
            frequency: newFrequency,
            lastUsed: Date(),
            averageDuration: newAverageDuration,
            context: context.merging(pattern.context) { new, _ in new }
        )

        interactionPatterns[action] = pattern

        // Trigger adaptation if threshold reached
        if newFrequency >= minimumInteractionsForAdaptation {
            adaptBasedOnPatterns()
        }

        saveState()
    }

    /// Update element visibility
    public func setVisibility(elementId: String, isVisible: Bool, priority: Int? = nil) {
        var pref = visibilityPreferences[elementId] ?? UIVisibilityPreference(elementId: elementId)
        pref.isVisible = isVisible
        if let priority = priority {
            pref.priority = priority
        }
        pref.lastModified = Date()
        visibilityPreferences[elementId] = pref

        saveState()
        logger.debug("Set visibility for \(elementId): \(isVisible)")
    }

    /// Get whether an element should be visible
    public func isVisible(_ elementId: String) -> Bool {
        visibilityPreferences[elementId]?.isVisible ?? true
    }

    /// Update layout setting
    public func updateLayout(_ update: (inout AdaptiveLayout) -> Void) {
        update(&layout)
        saveState()
    }

    /// Suggest optimal layout based on context
    public func suggestOptimalLayout() -> AdaptiveLayout {
        guard let context = context else { return layout }

        var suggested = layout

        // Adapt based on device
        switch context.deviceType {
        case .iPhone:
            suggested.showSidebar = false
            suggested.messageDisplayDensity = .compact
            suggested.chatInputPosition = .bottom

        case .iPad:
            suggested.showSidebar = context.screenSize.width > 768
            suggested.sidebarWidth = min(320, context.screenSize.width * 0.3)

        case .mac:
            suggested.showSidebar = true
            suggested.sidebarWidth = 280
            suggested.messageDisplayDensity = .comfortable

        case .watch:
            suggested.showSidebar = false
            suggested.messageDisplayDensity = .compact
            suggested.quickActions = ["send"]

        case .tv:
            suggested.messageDisplayDensity = .spacious
            suggested.theme.fontSize = .extraLarge

        case .vision:
            suggested.messageDisplayDensity = .spacious
            suggested.showSidebar = true
        }

        // Adapt based on time of day
        if suggested.theme.colorScheme == .auto {
            switch context.timeOfDay {
            case .night, .evening:
                // Would set dark mode preference
                break
            case .morning, .afternoon:
                // Would set light mode preference
                break
            }
        }

        // Adapt based on accessibility
        if context.isAccessibilityEnabled {
            suggested.theme.highContrast = true
            suggested.theme.reduceMotion = true
            if suggested.theme.fontSize == .medium {
                suggested.theme.fontSize = .large
            }
        }

        // Adapt based on session duration (reduce distractions for long sessions)
        if context.sessionDuration > 3600 { // > 1 hour
            suggested.quickActions = suggested.quickActions.prefix(2).map { $0 }
        }

        return suggested
    }

    /// Apply suggested layout
    public func applySuggestedLayout() {
        layout = suggestOptimalLayout()
        saveState()
        logger.info("Applied suggested layout")
    }

    /// Get quick actions based on context and patterns
    public func getContextualQuickActions(limit: Int = 4) -> [String] {
        // Get most frequently used actions
        let sortedActions = interactionPatterns.values
            .filter { Date().timeIntervalSince($0.lastUsed) < patternDetectionWindow }
            .sorted { $0.frequency > $1.frequency }
            .map(\.action)

        // Combine with current quick actions
        var actions = sortedActions.filter { layout.quickActions.contains($0) }

        // Add remaining from default if needed
        for action in layout.quickActions where !actions.contains(action) {
            actions.append(action)
            if actions.count >= limit { break }
        }

        return Array(actions.prefix(limit))
    }

    /// Get toolbar items based on usage
    public func getContextualToolbarItems(limit: Int = 5) -> [String] {
        let frequentActions = interactionPatterns.values
            .filter { $0.action.hasPrefix("toolbar.") }
            .sorted { $0.frequency > $1.frequency }
            .map { $0.action.replacingOccurrences(of: "toolbar.", with: "") }

        var items = frequentActions
        for item in layout.toolbarItems where !items.contains(item) {
            items.append(item)
        }

        return Array(items.prefix(limit))
    }

    /// Reset to defaults
    public func resetToDefaults() {
        layout = AdaptiveLayout()
        visibilityPreferences.removeAll()
        interactionPatterns.removeAll()
        saveState()
        logger.info("Reset adaptive UI to defaults")
    }

    // MARK: - Private Methods

    private func updateContext() {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeOfDay: UIContext.TimeOfDay
        switch hour {
        case 5..<12: timeOfDay = .morning
        case 12..<17: timeOfDay = .afternoon
        case 17..<21: timeOfDay = .evening
        default: timeOfDay = .night
        }

        #if os(macOS)
        let deviceType: UIContext.DeviceType = .mac
        let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
        #elseif os(iOS)
        let deviceType: UIContext.DeviceType = UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
        let screenSize = UIScreen.main.bounds.size
        #elseif os(watchOS)
        let deviceType: UIContext.DeviceType = .watch
        let screenSize = CGSize(width: 184, height: 224)
        #elseif os(tvOS)
        let deviceType: UIContext.DeviceType = .tv
        let screenSize = CGSize(width: 1920, height: 1080)
        #elseif os(visionOS)
        let deviceType: UIContext.DeviceType = .vision
        let screenSize = CGSize(width: 1920, height: 1080)
        #else
        let deviceType: UIContext.DeviceType = .mac
        let screenSize = CGSize(width: 1920, height: 1080)
        #endif

        context = UIContext(
            timeOfDay: timeOfDay,
            deviceType: deviceType,
            screenSize: screenSize,
            isAccessibilityEnabled: false, // Would check actual accessibility settings
            currentTask: nil,
            sessionDuration: 0
        )
    }

    private func startContextMonitoring() {
        // Update context periodically
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateContext()
            }
            .store(in: &cancellables)
    }

    private func adaptBasedOnPatterns() {
        guard adaptationEnabled else { return }

        // Analyze patterns and adapt
        let frequentActions = interactionPatterns.values
            .sorted { $0.frequency > $1.frequency }
            .prefix(10)

        // Auto-show frequently used elements
        for pattern in frequentActions {
            if pattern.frequency > minimumInteractionsForAdaptation * 2 {
                // Could auto-add to quick actions
                if !layout.quickActions.contains(pattern.action) && layout.quickActions.count < 6 {
                    layout.quickActions.append(pattern.action)
                }
            }
        }

        // Hide rarely used elements
        for (elementId, pref) in visibilityPreferences {
            if let pattern = interactionPatterns[elementId] {
                if pattern.frequency < 2 && Date().timeIntervalSince(pattern.lastUsed) > patternDetectionWindow {
                    var updatedPref = pref
                    updatedPref.priority -= 1
                    visibilityPreferences[elementId] = updatedPref
                }
            }
        }

        logger.debug("Adapted UI based on \(frequentActions.count) frequent patterns")
    }

    // MARK: - Persistence

    private func saveState() {
        let state = AdaptiveUIState(
            layout: layout,
            visibilityPreferences: Array(visibilityPreferences.values),
            interactionPatterns: Array(interactionPatterns.values)
        )

        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func loadState() {
        guard let data = defaults.data(forKey: storageKey),
              let state = try? JSONDecoder().decode(AdaptiveUIState.self, from: data) else {
            return
        }

        layout = state.layout
        visibilityPreferences = Dictionary(uniqueKeysWithValues: state.visibilityPreferences.map { ($0.elementId, $0) })
        interactionPatterns = Dictionary(uniqueKeysWithValues: state.interactionPatterns.map { ($0.action, $0) })

        logger.info("Loaded adaptive UI state")
    }
}

// MARK: - Persistence State

private struct AdaptiveUIState: Codable {
    let layout: AdaptiveLayout
    let visibilityPreferences: [UIVisibilityPreference]
    let interactionPatterns: [InteractionPattern]
}

// MARK: - SwiftUI View Modifiers

/// Modifier that tracks interactions
public struct InteractionTrackingModifier: ViewModifier {
    let actionName: String
    @StateObject private var engine = AdaptiveUIEngine.shared

    public func body(content: Content) -> some View {
        content
            .onTapGesture {
                engine.recordInteraction(action: actionName)
            }
    }
}

/// Modifier for adaptive visibility
public struct AdaptiveVisibilityModifier: ViewModifier {
    let elementId: String
    @StateObject private var engine = AdaptiveUIEngine.shared

    public func body(content: Content) -> some View {
        if engine.isVisible(elementId) {
            content
        }
    }
}

public extension View {
    /// Track interactions with this view
    func trackInteraction(_ actionName: String) -> some View {
        modifier(InteractionTrackingModifier(actionName: actionName))
    }

    /// Apply adaptive visibility
    func adaptiveVisibility(_ elementId: String) -> some View {
        modifier(AdaptiveVisibilityModifier(elementId: elementId))
    }
}
