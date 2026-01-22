//
//  FocusFilterService.swift
//  Thea
//
//  Focus Filters for customizing app behavior during Focus modes
//

import Foundation
import SwiftUI
import AppIntents

// MARK: - Focus Filter Configuration

@available(iOS 16.0, macOS 13.0, *)
struct TheaFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Thea Focus Settings"
    static var description: IntentDescription = "Configure Thea's behavior during this Focus mode"

    // MARK: - Filter Parameters

    @Parameter(title: "AI Response Style")
    var responseStyle: ResponseStyleEnum?

    @Parameter(title: "Enable Notifications")
    var notificationsEnabled: Bool?

    @Parameter(title: "Auto-summarize Messages")
    var autoSummarize: Bool?

    @Parameter(title: "Reduce Visual Complexity")
    var reduceComplexity: Bool?

    @Parameter(title: "Preferred AI Model")
    var preferredModel: AIModelEnum?

    @Parameter(title: "Quick Actions Only")
    var quickActionsOnly: Bool?

    @Parameter(title: "Allowed Features", default: [])
    var allowedFeatures: [FeatureEnum]

    // MARK: - Display

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Thea Focus Mode",
            subtitle: responseStyle.map { "Response style: \($0.localizedName)" } ?? "Default settings"
        )
    }

    // MARK: - Apply Filter

    func perform() async throws -> some IntentResult {
        await FocusFilterManager.shared.applyFilter(self)
        return .result()
    }
}

// MARK: - Focus Filter Manager

@MainActor
public class FocusFilterManager: ObservableObject {
    public static let shared = FocusFilterManager()

    // MARK: - Published State

    @Published public private(set) var activeFilter: ActiveFocusFilter?
    @Published public private(set) var isInFocusMode = false

    // MARK: - Current Settings

    public var responseStyle: ResponseStyle = .balanced
    public var notificationsEnabled = true
    public var autoSummarize = false
    public var reduceComplexity = false
    public var preferredModel: String?
    public var quickActionsOnly = false
    public var allowedFeatures: Set<Feature> = Set(Feature.allCases)

    // MARK: - Initialization

    private init() {}

    // MARK: - Filter Application

    @available(iOS 16.0, macOS 13.0, *)
    func applyFilter(_ filter: TheaFocusFilter) {
        isInFocusMode = true

        if let style = filter.responseStyle {
            responseStyle = ResponseStyle(from: style)
        }

        if let notifications = filter.notificationsEnabled {
            notificationsEnabled = notifications
        }

        if let summarize = filter.autoSummarize {
            autoSummarize = summarize
        }

        if let reduce = filter.reduceComplexity {
            reduceComplexity = reduce
        }

        if let model = filter.preferredModel {
            preferredModel = model.rawValue
        }

        if let quickOnly = filter.quickActionsOnly {
            quickActionsOnly = quickOnly
        }

        allowedFeatures = Set(filter.allowedFeatures.map { Feature(from: $0) })

        activeFilter = ActiveFocusFilter(
            responseStyle: responseStyle,
            notificationsEnabled: notificationsEnabled,
            autoSummarize: autoSummarize,
            reduceComplexity: reduceComplexity,
            preferredModel: preferredModel,
            quickActionsOnly: quickActionsOnly,
            allowedFeatures: allowedFeatures
        )
    }

    // MARK: - Reset

    public func resetToDefaults() {
        isInFocusMode = false
        responseStyle = .balanced
        notificationsEnabled = true
        autoSummarize = false
        reduceComplexity = false
        preferredModel = nil
        quickActionsOnly = false
        allowedFeatures = Set(Feature.allCases)
        activeFilter = nil
    }

    // MARK: - Feature Access

    public func isFeatureAllowed(_ feature: Feature) -> Bool {
        if !isInFocusMode { return true }
        return allowedFeatures.contains(feature)
    }

    public func shouldShowNotification(priority: NotificationPriority) -> Bool {
        if !isInFocusMode { return true }

        switch priority {
        case .critical: return true
        case .high: return notificationsEnabled
        case .normal, .low: return notificationsEnabled && !quickActionsOnly
        }
    }
}

// MARK: - App Intent Enums

@available(iOS 16.0, macOS 13.0, *)
enum ResponseStyleEnum: String, AppEnum {
    case concise
    case balanced
    case detailed
    case technical
    case creative

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Response Style")
    }

    static var caseDisplayRepresentations: [ResponseStyleEnum: DisplayRepresentation] {
        [
            .concise: "Concise - Brief, to-the-point responses",
            .balanced: "Balanced - Standard response length",
            .detailed: "Detailed - Comprehensive explanations",
            .technical: "Technical - In-depth technical details",
            .creative: "Creative - More expressive responses"
        ]
    }

    var localizedName: String {
        switch self {
        case .concise: return "Concise"
        case .balanced: return "Balanced"
        case .detailed: return "Detailed"
        case .technical: return "Technical"
        case .creative: return "Creative"
        }
    }
}

@available(iOS 16.0, macOS 13.0, *)
enum AIModelEnum: String, AppEnum {
    case claude = "claude"
    case gpt4 = "gpt4"
    case gemini = "gemini"
    case local = "local"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "AI Model")
    }

    static var caseDisplayRepresentations: [AIModelEnum: DisplayRepresentation] {
        [
            .claude: "Claude - Anthropic's AI",
            .gpt4: "GPT-4 - OpenAI's model",
            .gemini: "Gemini - Google's AI",
            .local: "Local - On-device model"
        ]
    }
}

@available(iOS 16.0, macOS 13.0, *)
enum FeatureEnum: String, AppEnum {
    case chat
    case codeGeneration
    case knowledge
    case projects
    case voice
    case health
    case financial
    case automation

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Feature")
    }

    static var caseDisplayRepresentations: [FeatureEnum: DisplayRepresentation] {
        [
            .chat: "Chat - Conversations",
            .codeGeneration: "Code - Code generation",
            .knowledge: "Knowledge - Knowledge base",
            .projects: "Projects - Project management",
            .voice: "Voice - Voice commands",
            .health: "Health - Health tracking",
            .financial: "Financial - Finance features",
            .automation: "Automation - Automations"
        ]
    }
}

// MARK: - Domain Types

public enum ResponseStyle: String, Sendable, CaseIterable {
    case concise
    case balanced
    case detailed
    case technical
    case creative

    @available(iOS 16.0, macOS 13.0, *)
    init(from appEnum: ResponseStyleEnum) {
        switch appEnum {
        case .concise: self = .concise
        case .balanced: self = .balanced
        case .detailed: self = .detailed
        case .technical: self = .technical
        case .creative: self = .creative
        }
    }
}

public enum Feature: String, Sendable, CaseIterable {
    case chat
    case codeGeneration
    case knowledge
    case projects
    case voice
    case health
    case financial
    case automation

    @available(iOS 16.0, macOS 13.0, *)
    init(from appEnum: FeatureEnum) {
        switch appEnum {
        case .chat: self = .chat
        case .codeGeneration: self = .codeGeneration
        case .knowledge: self = .knowledge
        case .projects: self = .projects
        case .voice: self = .voice
        case .health: self = .health
        case .financial: self = .financial
        case .automation: self = .automation
        }
    }
}

public enum NotificationPriority: Sendable {
    case critical
    case high
    case normal
    case low
}

public struct ActiveFocusFilter: Sendable {
    public let responseStyle: ResponseStyle
    public let notificationsEnabled: Bool
    public let autoSummarize: Bool
    public let reduceComplexity: Bool
    public let preferredModel: String?
    public let quickActionsOnly: Bool
    public let allowedFeatures: Set<Feature>
}

// MARK: - SwiftUI Modifiers

public extension View {
    /// Adjust view based on focus filter
    @ViewBuilder
    func focusFilterAware() -> some View {
        modifier(FocusFilterViewModifier())
    }
}

struct FocusFilterViewModifier: ViewModifier {
    @ObservedObject private var filterManager = FocusFilterManager.shared

    func body(content: Content) -> some View {
        content
            .animation(filterManager.reduceComplexity ? nil : .default, value: filterManager.isInFocusMode)
            .opacity(filterManager.isInFocusMode && filterManager.reduceComplexity ? 1 : 1)
    }
}
