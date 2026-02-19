//
//  TipKitService.swift
//  Thea
//
//  TipKit integration for feature discovery and user onboarding
//

import Foundation
import SwiftUI

#if canImport(TipKit)
    import TipKit
import OSLog

private let logger = Logger(subsystem: "ai.thea.app", category: "TipKitService")

    // MARK: - Tips Manager

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    @MainActor
    public class TipKitManager: ObservableObject {
        public static let shared = TipKitManager()

        @Published public private(set) var hasConfiguredTips = false

        private init() {}

        /// Configure TipKit for the app
        public func configure() async {
            do {
                try Tips.configure([
                    .displayFrequency(.immediate),
                    .datastoreLocation(.applicationDefault)
                ])
                hasConfiguredTips = true
            } catch {
                // TipKit configuration failed
            }
        }

        /// Reset all tips
        public func resetAllTips() async {
            do {
                try Tips.resetDatastore()
            } catch {
                logger.error("Failed to reset TipKit datastore: \(error.localizedDescription)")
            }
        }

        /// Show all tips immediately (for testing)
        public func showAllTipsForTesting() async {
            Tips.showAllTipsForTesting()
        }

        /// Hide all tips (for testing)
        public func hideAllTipsForTesting() async {
            Tips.hideAllTipsForTesting()
        }
    }

    // MARK: - Onboarding Tips

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    struct WelcomeTip: Tip {
        var title: Text {
            Text("Welcome to Thea")
        }

        var message: Text? {
            Text("Your AI assistant across all Apple devices. Tap to start a conversation.")
        }

        var image: Image? {
            Image(systemName: "brain")
        }

        var actions: [Action] {
            Action(id: "start-chat", title: "Start Chatting")
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    struct VoiceCommandTip: Tip {
        @Parameter
        // periphery:ignore - Reserved: hasUsedVoice static property — reserved for future feature activation
        static var hasUsedVoice: Bool = false

        var title: Text {
            Text("Try Voice Commands")
        }

        var message: Text? {
            Text("Hold the microphone button to speak to Thea hands-free.")
        // periphery:ignore - Reserved: hasUsedVoice static property reserved for future feature activation
        }

        var image: Image? {
            Image(systemName: "mic.fill")
        }

        var rules: [Rule] {
            #Rule(Self.$hasUsedVoice) { $0 == false }
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    struct CodeAssistantTip: Tip {
        @Parameter
        static var projectsViewed: Int = 0

        var title: Text {
            Text("AI Code Assistant")
        }

        var message: Text? {
            Text("Thea can help write, review, and debug code. Share a file or describe what you need.")
        }

        var image: Image? {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
        }

        var rules: [Rule] {
            #Rule(Self.$projectsViewed) { $0 >= 1 }
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    struct KnowledgeBaseTip: Tip {
        @Parameter
        static var conversationCount: Int = 0

        var title: Text {
            Text("Build Your Knowledge Base")
        }

        var message: Text? {
            Text("Thea learns from your conversations. Add important information to your personal knowledge base.")
        }

        var image: Image? {
            Image(systemName: "books.vertical.fill")
        }

        var rules: [Rule] {
            #Rule(Self.$conversationCount) { $0 >= 5 }
        }
    }

    // MARK: - Feature Discovery Tips

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    // periphery:ignore - Reserved: SharePlayTip type — reserved for future feature activation
    struct SharePlayTip: Tip {
        var title: Text {
            Text("Collaborate with SharePlay")
        }

        var message: Text? {
            Text("Start a SharePlay session to brainstorm with friends using Thea together.")
        // periphery:ignore - Reserved: SharePlayTip type reserved for future feature activation
        }

        var image: Image? {
            Image(systemName: "shareplay")
        }

        var options: [TipOption] {
            [Tips.MaxDisplayCount(3)]
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    // periphery:ignore - Reserved: WidgetTip type — reserved for future feature activation
    struct WidgetTip: Tip {
        var title: Text {
            Text("Add Thea Widgets")
        }

        var message: Text? {
            // periphery:ignore - Reserved: WidgetTip type reserved for future feature activation
            Text("Quick access to Thea from your Home Screen or Lock Screen.")
        }

        var image: Image? {
            Image(systemName: "square.grid.2x2")
        }

        var actions: [Action] {
            Action(id: "learn-more", title: "Learn More")
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    // periphery:ignore - Reserved: ShortcutsTip type — reserved for future feature activation
    struct ShortcutsTip: Tip {
        var title: Text {
            Text("Automate with Shortcuts")
        }

        // periphery:ignore - Reserved: ShortcutsTip type reserved for future feature activation
        var message: Text? {
            Text("Use Thea actions in Shortcuts to automate your workflow.")
        }

        var image: Image? {
            Image(systemName: "square.stack.3d.up.fill")
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    struct FocusModeTip: Tip {
        @Parameter
        // periphery:ignore - Reserved: hasFocusModeEnabled static property — reserved for future feature activation
        static var hasFocusModeEnabled: Bool = false

        var title: Text {
            Text("Focus Mode Integration")
        // periphery:ignore - Reserved: hasFocusModeEnabled static property reserved for future feature activation
        }

        var message: Text? {
            Text("Customize how Thea behaves during different Focus modes.")
        }

        var image: Image? {
            Image(systemName: "moon.fill")
        }

        var rules: [Rule] {
            #Rule(Self.$hasFocusModeEnabled) { $0 == false }
        }
    }

    // MARK: - Advanced Feature Tips

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    struct MCPServersTip: Tip {
        @Parameter
        // periphery:ignore - Reserved: isAdvancedUser static property — reserved for future feature activation
        static var isAdvancedUser: Bool = false

        var title: Text {
            // periphery:ignore - Reserved: isAdvancedUser static property reserved for future feature activation
            Text("Extend with MCP Servers")
        }

        var message: Text? {
            Text("Connect MCP servers to give Thea access to external tools and services.")
        }

        var image: Image? {
            Image(systemName: "server.rack")
        }

        var rules: [Rule] {
            #Rule(Self.$isAdvancedUser) { $0 == true }
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    // periphery:ignore - Reserved: LocalModelTip type — reserved for future feature activation
    struct LocalModelTip: Tip {
        var title: Text {
            // periphery:ignore - Reserved: LocalModelTip type reserved for future feature activation
            Text("On-Device AI Models")
        }

        var message: Text? {
            Text("Run AI models locally for privacy and offline access.")
        }

        var image: Image? {
            Image(systemName: "cpu")
        }

        var options: [TipOption] {
            [Tips.MaxDisplayCount(2)]
        }
    }

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    struct AutomationTip: Tip {
        @Parameter
        static var automationsCreated: Int = 0

        var title: Text {
            Text("Create Automations")
        }

        var message: Text? {
            Text("Set up automated workflows triggered by time, location, or events.")
        }

        var image: Image? {
            Image(systemName: "gearshape.2.fill")
        }

        var rules: [Rule] {
            #Rule(Self.$automationsCreated) { $0 == 0 }
        }
    }

    // MARK: - Platform-Specific Tips

    #if os(macOS)
        @available(macOS 14.0, *)
        // periphery:ignore - Reserved: MenuBarTip type — reserved for future feature activation
        struct MenuBarTip: Tip {
            // periphery:ignore - Reserved: MenuBarTip type reserved for future feature activation
            var title: Text {
                Text("Quick Access Menu")
            }

            var message: Text? {
                Text("Access Thea instantly from the menu bar with ⌘⇧T.")
            }

            var image: Image? {
                Image(systemName: "menubar.rectangle")
            }
        }

        @available(macOS 14.0, *)
        // periphery:ignore - Reserved: TerminalIntegrationTip type reserved for future feature activation
        struct TerminalIntegrationTip: Tip {
            var title: Text {
                Text("Terminal Integration")
            }

            var message: Text? {
                Text("Thea can execute commands and help with your terminal workflow.")
            }

            var image: Image? {
                Image(systemName: "terminal.fill")
            }
        }
    #endif

    #if os(iOS)
        @available(iOS 17.0, *)
        struct LiveActivityTip: Tip {
            var title: Text {
                Text("Dynamic Island")
            }

            var message: Text? {
                Text("Track AI progress right from the Dynamic Island during long tasks.")
            }

            var image: Image? {
                Image(systemName: "iphone.gen3")
            }
        }

        @available(iOS 17.0, *)
        struct ControlCenterTip: Tip {
            var title: Text {
                Text("Control Center Actions")
            }

            var message: Text? {
                Text("Add Thea controls to Control Center for instant access.")
            }

            var image: Image? {
                Image(systemName: "slider.horizontal.3")
            }
        }
    #endif

    #if os(watchOS)
        @available(watchOS 10.0, *)
        struct ComplicationTip: Tip {
            var title: Text {
                Text("Watch Face Complication")
            }

            var message: Text? {
                Text("Add Thea to your watch face for quick voice access.")
            }

            var image: Image? {
                Image(systemName: "applewatch")
            }
        }
    #endif

    // MARK: - Tip Events

    @available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *)
    public struct TipEvents {
        /// Record when user starts their first chat
        public static func recordFirstChat() {
            WelcomeTip().invalidate(reason: .actionPerformed)
        }

        /// Record voice command usage
        public static func recordVoiceUsage() {
            VoiceCommandTip.hasUsedVoice = true
        }

        /// Record project view
        public static func recordProjectView() {
            CodeAssistantTip.projectsViewed += 1
        }

        /// Record conversation count
        public static func recordConversation() {
            KnowledgeBaseTip.conversationCount += 1
        }

        /// Record automation creation
        public static func recordAutomationCreated() {
            AutomationTip.automationsCreated += 1
        }

        /// Mark user as advanced
        public static func markAsAdvancedUser() {
            MCPServersTip.isAdvancedUser = true
        }

        /// Record Focus mode enabled
        public static func recordFocusModeEnabled() {
            FocusModeTip.hasFocusModeEnabled = true
        }
    }

#endif

// MARK: - Fallback for Older OS

public enum TipKitFallback {
    public static func isAvailable() -> Bool {
        if #available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *) {
            return true
        }
        return false
    }
}
