// AccessibilityManager.swift
// Comprehensive accessibility support for Thea

import Foundation
import SwiftUI
import OSLog
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Accessibility Manager

/// Manages accessibility features across Thea
@MainActor
public final class AccessibilityManager: ObservableObject {
    public static let shared = AccessibilityManager()

    private let logger = Logger(subsystem: "com.thea.app", category: "Accessibility")
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published State

    @Published public private(set) var isVoiceOverRunning = false
    @Published public private(set) var isReduceMotionEnabled = false
    @Published public private(set) var isDifferentiateWithoutColorEnabled = false
    @Published public private(set) var isReduceTransparencyEnabled = false
    @Published public private(set) var isBoldTextEnabled = false
    @Published public private(set) var isInvertColorsEnabled = false
    @Published public private(set) var preferredContentSizeCategory: ContentSizeCategory = .medium

    // MARK: - Configuration

    @Published public var settings = AccessibilitySettings()

    // MARK: - Initialization

    private init() {
        loadSettings()
        setupObservers()
        updateAccessibilityState()
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "accessibility.settings"),
           let loaded = try? JSONDecoder().decode(AccessibilitySettings.self, from: data) {
            settings = loaded
        }
    }

    public func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "accessibility.settings")
        }
    }

    // MARK: - Setup

    private func setupObservers() {
        #if os(iOS)
        // VoiceOver
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAccessibilityState()
            }
            .store(in: &cancellables)

        // Reduce Motion
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAccessibilityState()
            }
            .store(in: &cancellables)

        // Bold Text
        NotificationCenter.default.publisher(for: UIAccessibility.boldTextStatusDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAccessibilityState()
            }
            .store(in: &cancellables)

        // Content Size
        NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAccessibilityState()
            }
            .store(in: &cancellables)
        #endif
    }

    private func updateAccessibilityState() {
        #if os(iOS)
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isDifferentiateWithoutColorEnabled = UIAccessibility.shouldDifferentiateWithoutColor
        isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
        isInvertColorsEnabled = UIAccessibility.isInvertColorsEnabled
        preferredContentSizeCategory = ContentSizeCategory(UIApplication.shared.preferredContentSizeCategory)
        #elseif os(macOS)
        isVoiceOverRunning = NSWorkspace.shared.isVoiceOverEnabled
        isReduceMotionEnabled = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        isReduceTransparencyEnabled = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        isDifferentiateWithoutColorEnabled = NSWorkspace.shared.accessibilityDisplayShouldDifferentiateWithoutColor
        #endif

        logger.debug("Accessibility state updated: VoiceOver=\(self.isVoiceOverRunning), ReduceMotion=\(self.isReduceMotionEnabled)")
    }

    // MARK: - Announcements

    /// Make a VoiceOver announcement
    public func announce(_ message: String, priority: AnnouncementPriority = .normal) {
        #if os(iOS)
        let notification: UIAccessibility.Notification
        switch priority {
        case .immediate:
            notification = .announcement
        case .normal:
            notification = .announcement
        case .screenChanged:
            notification = .screenChanged
        case .layoutChanged:
            notification = .layoutChanged
        }

        UIAccessibility.post(notification: notification, argument: message)
        #elseif os(macOS)
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
            .announcement: message,
            .priority: NSAccessibilityPriorityLevel.high
        ])
        #endif

        logger.debug("Accessibility announcement: \(message)")
    }

    /// Announce progress
    public func announceProgress(_ progress: Double, context: String) {
        let percentage = Int(progress * 100)
        announce("\(context): \(percentage)% complete")
    }

    /// Announce completion
    public func announceCompletion(_ message: String) {
        announce(message, priority: .immediate)
    }

    /// Announce error
    public func announceError(_ error: String) {
        announce("Error: \(error)", priority: .immediate)
    }

    // MARK: - Focus Management

    /// Move VoiceOver focus to element
    #if os(iOS)
    public func moveFocus(to element: Any?) {
        UIAccessibility.post(notification: .layoutChanged, argument: element)
    }
    #endif

    /// Notify screen change
    public func notifyScreenChanged(focus: Any? = nil) {
        #if os(iOS)
        UIAccessibility.post(notification: .screenChanged, argument: focus)
        #endif
    }

    /// Notify layout change
    public func notifyLayoutChanged(focus: Any? = nil) {
        #if os(iOS)
        UIAccessibility.post(notification: .layoutChanged, argument: focus)
        #endif
    }

    // MARK: - Motion & Animation

    /// Check if animations should be reduced
    public var shouldReduceAnimations: Bool {
        return isReduceMotionEnabled || settings.reduceAnimations
    }

    /// Get appropriate animation duration
    public func animationDuration(base: Double) -> Double {
        if shouldReduceAnimations {
            return 0
        }
        return settings.animationSpeed * base
    }

    /// Get appropriate transition
    public func transition(default defaultTransition: AnyTransition) -> AnyTransition {
        if shouldReduceAnimations {
            return .opacity
        }
        return defaultTransition
    }

    // MARK: - Color & Contrast

    /// Check if high contrast should be used
    public var shouldUseHighContrast: Bool {
        return isDifferentiateWithoutColorEnabled || settings.highContrast
    }

    /// Get accessible color variant
    public func accessibleColor(_ color: Color, highContrastAlternative: Color) -> Color {
        if shouldUseHighContrast {
            return highContrastAlternative
        }
        return color
    }

    // MARK: - Text

    /// Get scaled font size
    public func scaledFontSize(base: CGFloat) -> CGFloat {
        let scale = contentSizeScale
        return base * scale
    }

    private var contentSizeScale: CGFloat {
        switch preferredContentSizeCategory {
        case .extraSmall: return 0.8
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        case .extraLarge: return 1.2
        case .extraExtraLarge: return 1.3
        case .extraExtraExtraLarge: return 1.4
        case .accessibilityMedium: return 1.6
        case .accessibilityLarge: return 1.8
        case .accessibilityExtraLarge: return 2.0
        case .accessibilityExtraExtraLarge: return 2.2
        case .accessibilityExtraExtraExtraLarge: return 2.4
        @unknown default: return 1.0
        }
    }

    // MARK: - Haptics

    /// Provide haptic feedback (with accessibility consideration)
    public func hapticFeedback(_ type: HapticType) {
        guard settings.hapticsEnabled else { return }

        #if os(iOS)
        switch type {
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        }
        #endif
    }

    // MARK: - Alternative Content

    /// Get alternative text for AI response
    public func alternativeText(for response: String, summary: String?) -> String {
        if isVoiceOverRunning, let summary = summary {
            // Provide shorter summary for VoiceOver users
            return "AI Response Summary: \(summary). Full response available."
        }
        return response
    }

    /// Create accessibility description for conversation
    public func conversationDescription(
        title: String,
        messageCount: Int,
        lastMessage: String?
    ) -> String {
        var description = "\(title), \(messageCount) messages"
        if let last = lastMessage {
            description += ". Last message: \(last.prefix(100))"
        }
        return description
    }
}

// MARK: - Types

public struct AccessibilitySettings: Codable {
    public var reduceAnimations: Bool = false
    public var highContrast: Bool = false
    public var hapticsEnabled: Bool = true
    public var animationSpeed: Double = 1.0
    public var speakNotifications: Bool = false
    public var autoReadResponses: Bool = false
    public var largeButtons: Bool = false
    public var simplifiedUI: Bool = false

    public init() {}
}

public enum AnnouncementPriority {
    case immediate
    case normal
    case screenChanged
    case layoutChanged
}

public enum HapticType {
    case success
    case error
    case warning
    case selection
    case light
    case medium
    case heavy
}

// MARK: - ContentSizeCategory Extension

extension ContentSizeCategory {
    #if os(iOS)
    init(_ uiCategory: UIContentSizeCategory) {
        switch uiCategory {
        case .extraSmall: self = .extraSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .extraLarge: self = .extraLarge
        case .extraExtraLarge: self = .extraExtraLarge
        case .extraExtraExtraLarge: self = .extraExtraExtraLarge
        case .accessibilityMedium: self = .accessibilityMedium
        case .accessibilityLarge: self = .accessibilityLarge
        case .accessibilityExtraLarge: self = .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: self = .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: self = .accessibilityExtraExtraExtraLarge
        default: self = .medium
        }
    }
    #endif
}

// MARK: - SwiftUI View Modifiers

public struct AccessibleButtonStyle: ButtonStyle {
    @ObservedObject var accessibility = AccessibilityManager.shared

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(
                accessibility.shouldReduceAnimations ? nil : .easeInOut(duration: 0.1),
                value: configuration.isPressed
            )
    }
}

public struct ReducedMotionModifier: ViewModifier {
    @ObservedObject var accessibility = AccessibilityManager.shared
    let animation: Animation?

    public func body(content: Content) -> some View {
        content
            .animation(accessibility.shouldReduceAnimations ? nil : animation, value: UUID())
    }
}

public extension View {
    func accessibleAnimation(_ animation: Animation?) -> some View {
        modifier(ReducedMotionModifier(animation: animation))
    }

    func accessibilityAnnounce(_ message: String, when condition: Bool) -> some View {
        self.onChange(of: condition) { _, newValue in
            if newValue {
                AccessibilityManager.shared.announce(message)
            }
        }
    }
}

// MARK: - Accessible Labels

public struct AccessibleLabel {
    /// Create an accessibility label for a message
    public static func message(
        sender: String,
        content: String,
        timestamp: Date
    ) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let time = timeFormatter.string(from: timestamp)

        return "\(sender) said at \(time): \(content)"
    }

    /// Create an accessibility label for a conversation
    public static func conversation(
        title: String,
        preview: String?,
        unreadCount: Int
    ) -> String {
        var label = title
        if unreadCount > 0 {
            label += ", \(unreadCount) unread"
        }
        if let preview = preview {
            label += ". \(preview)"
        }
        return label
    }

    /// Create an accessibility label for an agent
    public static func agent(
        name: String,
        status: String,
        description: String
    ) -> String {
        return "\(name) agent, \(status). \(description)"
    }

    /// Create an accessibility label for progress
    public static func progress(
        percentage: Int,
        context: String
    ) -> String {
        return "\(context), \(percentage) percent complete"
    }
}
