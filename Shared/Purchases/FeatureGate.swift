//
//  FeatureGate.swift
//  Thea
//
//  Feature gating between free and pro tiers.
//  Checks StoreKitService entitlements to determine feature access.
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.thea.app", category: "FeatureGate")

/// Defines features that require a paid subscription or purchase.
enum ProFeature: String, CaseIterable, Sendable {
    // AI Features
    case unlimitedProviders = "Unlimited AI Providers"
    case modelComparison = "Model Comparison Mode"
    case advancedAgents = "Advanced Agent Delegation"
    case customSystemPrompts = "Custom System Prompts"

    // Intelligence
    case verificationPipeline = "Response Verification"
    case smartRouting = "Smart Model Routing"
    case conversationForking = "Conversation Forking"

    // Data & Privacy
    case healthDashboard = "Health Dashboard"
    case financialTracking = "Financial Tracking"
    case privacyFirewall = "Privacy Firewall"

    // Sync & Integration
    case crossDeviceSync = "Cross-Device Sync"
    case encryptedSync = "End-to-End Encrypted Sync"

    // Customization
    case premiumThemes = "Premium Themes"
    case advancedAutomation = "Advanced Automation"

    var description: String {
        switch self {
        case .unlimitedProviders: "Connect to unlimited AI providers"
        case .modelComparison: "Compare responses from multiple models side-by-side"
        case .advancedAgents: "Delegate complex tasks to specialized AI agents"
        case .customSystemPrompts: "Customize AI personality and behavior per conversation"
        case .verificationPipeline: "Verify AI responses with multi-source fact-checking"
        case .smartRouting: "Automatically route queries to the best AI model"
        case .conversationForking: "Branch conversations to explore different directions"
        case .healthDashboard: "HealthKit integration with trend analysis and coaching"
        case .financialTracking: "Transaction tracking, budgets, and tax estimation"
        case .privacyFirewall: "Default-deny outbound data firewall with audit log"
        case .crossDeviceSync: "Sync conversations and data across all your devices"
        case .encryptedSync: "AES-256-GCM encryption for all synced data"
        case .premiumThemes: "Additional visual themes and customization options"
        case .advancedAutomation: "Autonomous task execution and workflow automation"
        }
    }

    var icon: String {
        switch self {
        case .unlimitedProviders: "server.rack"
        case .modelComparison: "rectangle.split.2x1"
        case .advancedAgents: "person.2.circle"
        case .customSystemPrompts: "text.bubble"
        case .verificationPipeline: "checkmark.shield"
        case .smartRouting: "arrow.triangle.branch"
        case .conversationForking: "arrow.branch"
        case .healthDashboard: "heart.fill"
        case .financialTracking: "chart.bar.fill"
        case .privacyFirewall: "lock.shield"
        case .crossDeviceSync: "arrow.triangle.2.circlepath"
        case .encryptedSync: "lock.fill"
        case .premiumThemes: "paintpalette"
        case .advancedAutomation: "gearshape.2"
        }
    }

    /// Features included in the free tier (limited versions).
    static let freeFeatures: Set<ProFeature> = [
        .customSystemPrompts,
        .conversationForking,
    ]
}

/// Tier definitions for the subscription model.
enum SubscriptionTier: String, CaseIterable, Sendable {
    case free = "Free"
    case pro = "Pro"
    case team = "Team"

    var features: [ProFeature] {
        switch self {
        case .free:
            return Array(ProFeature.freeFeatures)
        case .pro:
            return ProFeature.allCases.filter { $0 != .advancedAgents }
        case .team:
            return ProFeature.allCases
        }
    }

    var monthlyPrice: String {
        switch self {
        case .free: "Free"
        case .pro: "$9.99/mo"
        case .team: "$29.99/mo"
        }
    }

    var annualPrice: String {
        switch self {
        case .free: "Free"
        case .pro: "$99.99/yr"
        case .team: "$299.99/yr"
        }
    }

    var description: String {
        switch self {
        case .free: "Basic AI chat with 1 provider"
        case .pro: "Full AI suite with all features"
        case .team: "Everything in Pro plus agent delegation"
        }
    }

    var badge: String {
        switch self {
        case .free: ""
        case .pro: "PRO"
        case .team: "TEAM"
        }
    }
}

/// Central feature gating utility.
/// Checks StoreKitService entitlements to determine if a feature is accessible.
@MainActor
enum FeatureGate {

    /// Whether the given feature is accessible with the current subscription.
    static func isAvailable(_ feature: ProFeature) -> Bool {
        let store = StoreKitService.shared

        // Free features are always available
        if ProFeature.freeFeatures.contains(feature) {
            return true
        }

        // Pro features require pro subscription
        if store.isPro {
            // Team-only features
            if feature == .advancedAgents {
                return store.isTeam
            }
            return true
        }

        // Check individual purchases
        switch feature {
        case .premiumThemes:
            return store.hasPremiumThemes
        case .advancedAutomation:
            return store.hasAdvancedAutomation
        default:
            return false
        }
    }

    /// The current subscription tier based on StoreKitService state.
    static var currentTier: SubscriptionTier {
        let store = StoreKitService.shared
        if store.isTeam {
            return .team
        } else if store.isPro {
            return .pro
        }
        return .free
    }

    /// Number of AI providers allowed in the current tier.
    static var maxProviders: Int {
        switch currentTier {
        case .free: 1
        case .pro, .team: .max
        }
    }

    /// Number of daily messages in the current tier.
    static var dailyMessageLimit: Int {
        switch currentTier {
        case .free: 50
        case .pro, .team: .max
        }
    }

    /// Maximum conversation history depth in free tier.
    static var maxConversationHistory: Int {
        switch currentTier {
        case .free: 100
        case .pro, .team: .max
        }
    }
}
