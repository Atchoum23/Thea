//
//  AccessibilityService.swift
//  Thea
//
//  Enhanced accessibility features for all platforms
//

import Combine
import Foundation
import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif
#if canImport(AppKit)
    import AppKit
#endif
#if canImport(AVFoundation)
    import AVFoundation
#endif

// MARK: - Accessibility Service

/// Service for managing accessibility features across all platforms
@MainActor
public class AccessibilityService: ObservableObject {
    public static let shared = AccessibilityService()

    // MARK: - Published State

    @Published public private(set) var isVoiceOverRunning = false
    @Published public private(set) var isReduceMotionEnabled = false
    @Published public private(set) var isDifferentiateWithoutColorEnabled = false
    @Published public private(set) var isBoldTextEnabled = false
    @Published public private(set) var preferredContentSizeCategory: ContentSizeCategory = .medium
    @Published public private(set) var isReduceTransparencyEnabled = false
    @Published public private(set) var isInvertColorsEnabled = false
    @Published public private(set) var isSwitchControlRunning = false
    @Published public private(set) var isVoiceControlRunning = false
    @Published public private(set) var isClosedCaptioningEnabled = false

    // MARK: - Custom Accessibility Settings

    @Published public var highContrastMode = false
    @Published public var largerTouchTargets = false
    @Published public var simplifiedInterface = false
    @Published public var readAloudResponses = false
    @Published public var hapticFeedbackEnabled = true
    @Published public var audioDescriptionsEnabled = false
    @Published public var customFontScale: Double = 1.0

    // MARK: - Announcements

    private var announcementQueue: [String] = []
    private var isProcessingAnnouncements = false

    // MARK: - Initialization

    private init() {
        setupAccessibilityObservers()
        loadCustomSettings()
    }

    // MARK: - Setup

    private func setupAccessibilityObservers() {
        #if os(iOS)
            // Observe VoiceOver
            NotificationCenter.default.addObserver(
                forName: UIAccessibility.voiceOverStatusDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
                }
            }

            // Observe Reduce Motion
            NotificationCenter.default.addObserver(
                forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
                }
            }

            // Observe Bold Text
            NotificationCenter.default.addObserver(
                forName: UIAccessibility.boldTextStatusDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
                }
            }

            // Observe Switch Control
            NotificationCenter.default.addObserver(
                forName: UIAccessibility.switchControlStatusDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isSwitchControlRunning = UIAccessibility.isSwitchControlRunning
                }
            }

            // Initial state
            isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
            isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
            isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
            isSwitchControlRunning = UIAccessibility.isSwitchControlRunning
            isDifferentiateWithoutColorEnabled = UIAccessibility.shouldDifferentiateWithoutColor
            isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
            isInvertColorsEnabled = UIAccessibility.isInvertColorsEnabled
            isClosedCaptioningEnabled = UIAccessibility.isClosedCaptioningEnabled
        #endif

        #if os(macOS)
            // macOS accessibility observations
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.updateMacOSAccessibilitySettings()
                }
            }

            updateMacOSAccessibilitySettings()
        #endif
    }

    #if os(macOS)
        private func updateMacOSAccessibilitySettings() {
            isReduceMotionEnabled = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            isReduceTransparencyEnabled = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
            isDifferentiateWithoutColorEnabled = NSWorkspace.shared.accessibilityDisplayShouldDifferentiateWithoutColor
            isInvertColorsEnabled = NSWorkspace.shared.accessibilityDisplayShouldInvertColors
        }
    #endif

    // MARK: - Custom Settings Persistence

    private func loadCustomSettings() {
        let defaults = UserDefaults.standard
        highContrastMode = defaults.bool(forKey: "accessibility.highContrast")
        largerTouchTargets = defaults.bool(forKey: "accessibility.largerTouchTargets")
        simplifiedInterface = defaults.bool(forKey: "accessibility.simplifiedInterface")
        readAloudResponses = defaults.bool(forKey: "accessibility.readAloud")
        hapticFeedbackEnabled = defaults.object(forKey: "accessibility.haptic") as? Bool ?? true
        audioDescriptionsEnabled = defaults.bool(forKey: "accessibility.audioDescriptions")
        customFontScale = defaults.double(forKey: "accessibility.fontScale")
        if customFontScale == 0 { customFontScale = 1.0 }
    }

    public func saveCustomSettings() {
        let defaults = UserDefaults.standard
        defaults.set(highContrastMode, forKey: "accessibility.highContrast")
        defaults.set(largerTouchTargets, forKey: "accessibility.largerTouchTargets")
        defaults.set(simplifiedInterface, forKey: "accessibility.simplifiedInterface")
        defaults.set(readAloudResponses, forKey: "accessibility.readAloud")
        defaults.set(hapticFeedbackEnabled, forKey: "accessibility.haptic")
        defaults.set(audioDescriptionsEnabled, forKey: "accessibility.audioDescriptions")
        defaults.set(customFontScale, forKey: "accessibility.fontScale")
    }

    // MARK: - Announcements

    /// Announce text to VoiceOver users
    public func announce(_ message: String, priority: AnnouncementPriority = .high) {
        #if os(iOS)
            // Use attributed string with priority for iOS
            let priorityValue = priority == .high ? UIAccessibilityPriority.high : UIAccessibilityPriority.low
            let attributedMessage = NSAttributedString(
                string: message,
                attributes: [.accessibilitySpeechAnnouncementPriority: priorityValue]
            )
            UIAccessibility.post(notification: .announcement, argument: attributedMessage)
        #elseif os(macOS)
            NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
                NSAccessibility.NotificationUserInfoKey.announcement: message,
                NSAccessibility.NotificationUserInfoKey.priority: priority == .high ? NSAccessibilityPriorityLevel.high : NSAccessibilityPriorityLevel.low
            ])
        #endif
    }

    /// Queue an announcement
    public func queueAnnouncement(_ message: String) {
        announcementQueue.append(message)
        processAnnouncementQueue()
    }

    private func processAnnouncementQueue() {
        guard !isProcessingAnnouncements, !announcementQueue.isEmpty else { return }

        isProcessingAnnouncements = true
        let message = announcementQueue.removeFirst()
        announce(message)

        Task {
            try? await Task.sleep(for: .seconds(2)) // 2 second delay
            isProcessingAnnouncements = false
            processAnnouncementQueue()
        }
    }

    // MARK: - Focus Management

    /// Post a focus change notification
    public func moveFocus(to element: Any?) {
        #if os(iOS)
            UIAccessibility.post(notification: .screenChanged, argument: element)
        #elseif os(macOS)
            if let nsElement = element {
                NSAccessibility.post(element: nsElement as AnyObject, notification: .focusedUIElementChanged)
            }
        #endif
    }

    /// Post a layout change notification
    public func announceLayoutChange(focusElement: Any? = nil) {
        #if os(iOS)
            UIAccessibility.post(notification: .layoutChanged, argument: focusElement)
        #endif
    }

    // MARK: - Haptic Feedback

    /// Provide haptic feedback
    public func provideHapticFeedback(_ type: HapticType) {
        guard hapticFeedbackEnabled else { return }

        #if os(iOS)
            switch type {
            case .success:
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            case .warning:
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
            case .error:
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
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

    // MARK: - Text to Speech

    /// Read text aloud
    public func speak(_ text: String, language: String = "en-US") {
        #if canImport(AVFoundation)
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: language)
            utterance.rate = 0.5

            let synthesizer = AVSpeechSynthesizer()
            synthesizer.speak(utterance)
        #endif
    }

    /// Stop speaking
    public func stopSpeaking() {
        #if canImport(AVFoundation)
            let synthesizer = AVSpeechSynthesizer()
            synthesizer.stopSpeaking(at: .immediate)
        #endif
    }

    // MARK: - Accessibility Labels

    /// Generate an accessible description for AI response
    public func describeAIResponse(_ response: String, wordCount: Int, isComplete: Bool) -> String {
        let status = isComplete ? "Complete response" : "Response in progress"
        return "\(status). \(wordCount) words. \(response.prefix(200))"
    }

    /// Generate accessibility hint for interactive elements
    public func hintForAction(_ action: String) -> String {
        switch action {
        case "send": "Double tap to send message to Thea"
        case "copy": "Double tap to copy to clipboard"
        case "share": "Double tap to open sharing options"
        case "speak": "Double tap to have Thea read this aloud"
        default: "Double tap to \(action)"
        }
    }
}

// MARK: - Supporting Types

public enum AnnouncementPriority {
    case high
    case low
}

public enum HapticType {
    case success
    case warning
    case error
    case selection
    case light
    case medium
    case heavy
}

// MARK: - View Modifiers

public extension View {
    /// Apply accessibility enhancements based on user settings
    func theaAccessible() -> some View {
        modifier(TheaAccessibilityModifier())
    }

    /// Apply larger touch targets when enabled
    func accessibleTouchTarget() -> some View {
        modifier(AccessibleTouchTargetModifier())
    }
}

struct TheaAccessibilityModifier: ViewModifier {
    @ObservedObject private var accessibility = AccessibilityService.shared

    func body(content: Content) -> some View {
        content
            .environment(\.sizeCategory, accessibility.preferredContentSizeCategory)
            .scaleEffect(accessibility.customFontScale)
    }
}

struct AccessibleTouchTargetModifier: ViewModifier {
    @ObservedObject private var accessibility = AccessibilityService.shared

    func body(content: Content) -> some View {
        content
            .frame(
                minWidth: accessibility.largerTouchTargets ? 44 : nil,
                minHeight: accessibility.largerTouchTargets ? 44 : nil
            )
    }
}

// MARK: - Accessibility Labels Extension

public extension String {
    /// Format for VoiceOver reading of code
    var accessibleCodeDescription: String {
        // Replace common symbols with words for better VoiceOver
        replacingOccurrences(of: "{", with: " open brace ")
            .replacingOccurrences(of: "}", with: " close brace ")
            .replacingOccurrences(of: "(", with: " open paren ")
            .replacingOccurrences(of: ")", with: " close paren ")
            .replacingOccurrences(of: "[", with: " open bracket ")
            .replacingOccurrences(of: "]", with: " close bracket ")
            .replacingOccurrences(of: "->", with: " returns ")
            .replacingOccurrences(of: "==", with: " equals ")
            .replacingOccurrences(of: "!=", with: " not equals ")
            .replacingOccurrences(of: "&&", with: " and ")
            .replacingOccurrences(of: "||", with: " or ")
    }
}
